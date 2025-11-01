--1 primero se ejecuta el de consorcios
sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

EXEC master.dbo.sp_MSset_oledb_prop 
    N'Microsoft.ACE.OLEDB.16.0', 
    N'AllowInProcess', 1;
    
EXEC master.dbo.sp_MSset_oledb_prop 
    N'Microsoft.ACE.OLEDB.16.0', 
    N'DynamicParameters', 1;

GO



CREATE OR ALTER PROCEDURE ImportarConsorciosDesdeExcel
    @RutaArchivo NVARCHAR(500),
    @NombreHoja NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Iniciando importación...';

    -- Crear tabla temporal con identity para iterar
    CREATE TABLE #TempConsorcios (
        ID INT IDENTITY(1,1),
        Consorcio VARCHAR(50),
        NombreConsorcio VARCHAR(100),
        Direccion NVARCHAR(200),
        CantUnidades INT,
        SuperficieTotal DECIMAL(10,2)
    );

    -- Leer datos del Excel a temporal
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
    INSERT INTO #TempConsorcios 
    SELECT 
        [Consorcio],
        [Nombre del consorcio],
        [Domicilio],
        [Cant unidades funcionales],
        [m2 totales]
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.16.0'', 
        ''Excel 12.0;HDR=YES;Database=' + @RutaArchivo + ''', 
        ''SELECT * FROM [' + @NombreHoja + '$]''
    )';

    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT 'Registros leídos del Excel: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'Error al leer el archivo Excel: ' + ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- Mostrar lo que se leyó
    SELECT * FROM #TempConsorcios;

    -- Variables para el bucle
    DECLARE @ID INT = 1;
    DECLARE @MaxID INT;
    DECLARE @NombreConsorcio VARCHAR(100);
    DECLARE @Direccion NVARCHAR(200);
    DECLARE @CantUnidades INT;
    DECLARE @SuperficieTotal DECIMAL(10,2);
    DECLARE @Contador INT = 0;

    -- Obtener el máximo ID
    SELECT @MaxID = MAX(ID) FROM #TempConsorcios;

    -- Bucle WHILE para procesar cada registro
    WHILE @ID <= @MaxID
    BEGIN
        -- Obtener datos del registro actual
        SELECT 
            @NombreConsorcio = NombreConsorcio,
            @Direccion = Direccion,
            @CantUnidades = CantUnidades,
            @SuperficieTotal = SuperficieTotal
        FROM #TempConsorcios 
        WHERE ID = @ID;

        -- Verificar si el consorcio ya existe y procesar si no existe
        IF NOT EXISTS (
            SELECT 1 
            FROM consorcio.Consorcio c 
            WHERE c.Direccion = @Direccion 
              AND c.NombreConsorcio = @NombreConsorcio
        )
        BEGIN
            BEGIN TRY
                -- Ejecutar el stored procedure
                EXEC consorcio.sp_agrConsorcio 
                    @NombreConsorcio,
                    @Direccion,
                    @SuperficieTotal,
                    @CantUnidades,
                    2.00,  -- MoraPrimerVTO
                    5.00;  -- MoraProxVTO

                SET @Contador = @Contador + 1;
                PRINT 'Consorcio procesado: ' + @NombreConsorcio;
            END TRY
            BEGIN CATCH
                PRINT 'Error al procesar consorcio ' + ISNULL(@NombreConsorcio, 'N/A') + ': ' + ERROR_MESSAGE();
            END CATCH
        END
        ELSE
        BEGIN
            PRINT 'Consorcio ya existe, omitiendo: ' + @NombreConsorcio;
        END

        SET @ID = @ID + 1;
    END;

    PRINT 'Importación completada. Registros procesados: ' + CAST(@Contador AS VARCHAR(10));

    -- Limpiar
    DROP TABLE #TempConsorcios;
END;
GO

/*Probar*/

EXEC ImportarConsorciosDesdeExcel 
    @RutaArchivo = 'C:\Archivos_para_el_TP\datos varios.xlsx',
    @NombreHoja = N'Consorcios';

select * from consorcio.Consorcio


--segundo, cargo la unidad funcional

create or alter procedure consorcio.importarunidadesfuncionales
    @rutaarch nvarchar(255)
as
begin 
    set nocount on;
    
    declare @hash varchar(64);
    declare @nombrearchivo nvarchar(255);
    
    begin try
        -- obtener nombre del archivo
        set @nombrearchivo = right(@rutaarch, charindex('\', reverse(@rutaarch)) - 1);

        print '=== iniciando importación de unidades funcionales ===';
        print 'archivo: ' + @nombrearchivo;
        
        -- 1. crear tabla temporal
        if object_id('tempdb..#ufstemp') is not null
            drop table #ufstemp;

        create table #ufstemp (
            [nombre del consorcio] nvarchar(100),
            nrounidadfuncional nvarchar(10),
            piso nvarchar(10),
            departamento nvarchar(10),
            coeficiente nvarchar(10),  
            m2_unidad_funcional nvarchar(10),
            bauleras nvarchar(10),
            cochera nvarchar(10),
            m2_baulera nvarchar(10),
            m2_cochera nvarchar(10)
        );

        -- 2. importar archivo
        print 'importando archivo...';
        declare @sql nvarchar(max);
        
        set @sql = N'bulk insert #ufstemp from ''' + @rutaarch + ''' with (
            firstrow = 2,  
            fieldterminator = ''\t'',
            rowterminator = ''\n'',
            codepage = ''65001'',
            maxerrors = 1000
        )';
        
        exec sp_executesql @sql;
        
        declare @registrosleidos int = @@rowcount;
        print 'registros leídos del archivo: ' + cast(@registrosleidos as varchar);
        
        -- 3. limpiar datos vacíos
        delete from #ufstemp
        where ltrim(rtrim(isnull([nombre del consorcio], ''))) = '';

        -- 4. crear tabla temporal para consorcios nuevos
        if object_id('tempdb..#consorciosnuevos') is not null
            drop table #consorciosnuevos;

        create table #consorciosnuevos (
            nombreconsorcio nvarchar(100)
        );

        -- insertar consorcios que no existen
        insert into #consorciosnuevos (nombreconsorcio)
        select distinct ltrim(rtrim(t.[nombre del consorcio]))
        from #ufstemp t
        where not exists (
            select 1 
            from consorcio.consorcio c 
            where c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        );

        -- 5. insertar nuevos consorcios
        insert into consorcio.consorcio (nombreconsorcio, direccion, superficie_total, moraprimervto, moraproxvto)
        select 
            nombreconsorcio,
            'direccion ' + nombreconsorcio,
            1000.00,
            2.00,
            5.00
        from #consorciosnuevos;


        drop table #consorciosnuevos;

        -- 6. insertar unidades funcionales
        insert into consorcio.unidadfuncional (piso, depto, superficie, coeficiente, idconsorcio)
        select 
            ltrim(rtrim(t.piso)),
            ltrim(rtrim(t.departamento)),
            case 
                when isnumeric(t.m2_unidad_funcional) = 1 
                then cast(t.m2_unidad_funcional as decimal(6,2))
                else 0 
            end as superficie,
            case 
                when isnumeric(replace(t.coeficiente, ',', '.')) = 1 
                then cast(replace(t.coeficiente, ',', '.') as decimal(5,2))
                else 0 
            end as coeficiente,
            c.idconsorcio
        from #ufstemp t
        inner join consorcio.consorcio c 
            on c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        where ltrim(rtrim(isnull(t.piso, ''))) != ''
          and ltrim(rtrim(isnull(t.departamento, ''))) != '';

        declare @totalufs int = @@rowcount;
        
        -- 7. insertar bauleras
        insert into consorcio.baulera (tamanio, iduf)
        select 
            case 
                when isnumeric(t.m2_baulera) = 1 
                then cast(t.m2_baulera as decimal(10,2))
                else 0 
            end as tamanio,
            uf.iduf
        from #ufstemp t
        inner join consorcio.consorcio c 
            on c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        inner join consorcio.unidadfuncional uf 
            on uf.piso = ltrim(rtrim(t.piso)) 
            and uf.depto = ltrim(rtrim(t.departamento))
            and uf.idconsorcio = c.idconsorcio
        where ltrim(rtrim(isnull(t.bauleras, ''))) = 'si'
          and isnumeric(t.m2_baulera) = 1
          and cast(t.m2_baulera as decimal(10,2)) > 0;

        declare @totalbauleras int = @@rowcount;

        -- 8. insertar cocheras
        insert into consorcio.cochera (tamanio, iduf)
        select 
            case 
                when isnumeric(t.m2_cochera) = 1 
                then cast(t.m2_cochera as decimal(10,2))
                else 0 
            end as tamanio,
            uf.iduf
        from #ufstemp t
        inner join consorcio.consorcio c 
            on c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        inner join consorcio.unidadfuncional uf 
            on uf.piso = ltrim(rtrim(t.piso)) 
            and uf.depto = ltrim(rtrim(t.departamento))
            and uf.idconsorcio = c.idconsorcio
        where ltrim(rtrim(isnull(t.cochera, ''))) = 'si'
          and isnumeric(t.m2_cochera) = 1
          and cast(t.m2_cochera as decimal(10,2)) > 0;

        declare @totalcocheras int = @@rowcount;

        -- 9. solo mensajes de resumen, sin select
        print 'resultados:';
        print 'total uf: ' + cast(@totalufs as varchar);
        print 'total bauleras: ' + cast(@totalbauleras as varchar);
        print 'total cocheras: ' + cast(@totalcocheras as varchar);
        
        drop table #ufstemp;
        
        print ' importación completada';

    end try
    begin catch
        print 'error: ' + error_message();
        print 'linea: ' + cast(error_line() as varchar);
        if object_id('tempdb..#ufstemp') is not null
            drop table #ufstemp;
        if object_id('tempdb..#consorciosnuevos') is not null
            drop table #consorciosnuevos;
        throw;
    end catch
end
go

exec consorcio.importarunidadesfuncionales @rutaarch = 'c:\archivos_para_el_tp\uf por consorcio.txt'

select * from consorcio.unidadfuncional
select * from consorcio.Cochera
select * from consorcio.Baulera

--tercero, cargo personas
CREATE OR ALTER PROCEDURE consorcio.importarPersonas
    @rutaArchPersonas NVARCHAR(255),
    @rutaArchUF NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        PRINT 'Iniciando importación desde archivos CSV...';

   
        IF OBJECT_ID('tempdb..#tempPersonas') IS NOT NULL
            DROP TABLE #tempPersonas;

        CREATE TABLE #tempPersonas (
            Nombre NVARCHAR(50),
            Apellido NVARCHAR(50),
            DNI VARCHAR(10),
            Email NVARCHAR(100),
            Telefono NVARCHAR(15),
            CVU_CBU CHAR(22),
            Inquilino INT
        );

        SET @sql = N'BULK INSERT #tempPersonas FROM ''' + @rutaArchPersonas + ''' 
        WITH (FIRSTROW = 2, FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        PRINT 'Datos de personas cargados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL
            DROP TABLE #tempUF;

        CREATE TABLE #tempUF (
            CVU_CBU CHAR(22),
            NombreConsorcio NVARCHAR(50),
            NroUF INT,
            Piso NVARCHAR(10),
            Departamento NVARCHAR(10)
        );

        SET @sql = N'BULK INSERT #tempUF FROM ''' + @rutaArchUF + ''' 
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ''|'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        PRINT 'Datos de UF cargados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        PRINT 'Eliminando duplicados...';
        
        IF OBJECT_ID('tempdb..#personasSinDuplicados') IS NOT NULL
            DROP TABLE #personasSinDuplicados;

        SELECT 
            DNI = LTRIM(RTRIM(DNI)),
            Nombre = LEFT(LTRIM(RTRIM(Nombre)), 30),
            Apellido = LEFT(LTRIM(RTRIM(Apellido)), 30),
            Email = CASE WHEN LTRIM(RTRIM(Email)) = '' THEN NULL ELSE LEFT(LTRIM(RTRIM(Email)), 40) END,
            Telefono = CASE WHEN LTRIM(RTRIM(Telefono)) = '' THEN NULL ELSE LEFT(LTRIM(RTRIM(Telefono)), 15) END,
            CVU_CBU = LTRIM(RTRIM(CVU_CBU)),
            Inquilino = Inquilino,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(DNI)) ORDER BY (SELECT NULL)) as RowNum
        INTO #personasSinDuplicados
        FROM #tempPersonas;

        DELETE FROM #personasSinDuplicados WHERE RowNum > 1;

        PRINT 'Duplicados eliminados del archivo: ' + CAST(@@ROWCOUNT AS VARCHAR);


        PRINT 'Insertando datos en tabla Persona...';
        
        INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, idUF)
        SELECT 
            p.DNI,
            p.Nombre,
            p.Apellido,
            p.Email,
            p.Telefono,
            p.CVU_CBU,
            u.NroUF
        FROM #personasSinDuplicados p
        INNER JOIN #tempUF u ON p.CVU_CBU = LTRIM(RTRIM(u.CVU_CBU))
        WHERE NOT EXISTS (SELECT 1 FROM consorcio.Persona WHERE DNI = p.DNI);

        PRINT 'Personas insertadas: ' + CAST(@@ROWCOUNT AS VARCHAR);

        DROP TABLE #tempPersonas;
        DROP TABLE #tempUF;
        DROP TABLE #personasSinDuplicados;

        PRINT 'Importación completada exitosamente.';

    END TRY
    BEGIN CATCH
        PRINT 'Error durante la importación: ' + ERROR_MESSAGE();
        IF OBJECT_ID('tempdb..#tempPersonas') IS NOT NULL DROP TABLE #tempPersonas;
        IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL DROP TABLE #tempUF;
        IF OBJECT_ID('tempdb..#personasSinDuplicados') IS NOT NULL DROP TABLE #personasSinDuplicados;
        THROW;
    END CATCH
END
GO

exec consorcio.importarPersonas 
@rutaArchPersonas = 'c:\archivos_para_el_tp\inquilino-propietarios-datos.csv', 
@rutaArchUF = 'c:\archivos_para_el_tp\inquilino-propietarios-UF.csv'

select * from consorcio.Persona

--cuarto, importo ocupacion

create or alter procedure consorcio.importarocupaciones
	@rutaarchpersonas nvarchar(255),
	@rutaarchuf nvarchar(255)
as
begin
	set nocount on;

	declare @sql nvarchar(max);

	begin try
		print 'iniciando importación de ocupaciones desde archivos csv...';

		-- cargar datos temporales
		if object_id('tempdb..#temppersonas') is not null drop table #temppersonas;
		if object_id('tempdb..#tempuf') is not null drop table #tempuf;

		create table #temppersonas (
			nombre nvarchar(50), apellido nvarchar(50), dni varchar(10),
			email nvarchar(100), telefono nvarchar(15), cvu_cbu char(22), inquilino int
		);

		create table #tempuf (
			cvu_cbu char(22), nombreconsorcio nvarchar(50), nrouf int,
			piso nvarchar(10), departamento nvarchar(10)
		);

		set @sql = N'bulk insert #temppersonas from ''' + @rutaarchpersonas + ''' with (firstrow = 2, fieldterminator = '';'', rowterminator = ''\n'', codepage = ''65001'')';
		exec sp_executesql @sql;

		set @sql = N'bulk insert #tempuf from ''' + @rutaarchuf + ''' with (firstrow = 2, fieldterminator = ''|'', rowterminator = ''\n'', codepage = ''65001'')';
		exec sp_executesql @sql;

	
		declare @registrosinsertados int = 0;
		declare @registrosfallidos int = 0;

		-- crear tabla temporal con los datos procesados
		if object_id('tempdb..#datosparaocupacion') is not null
			drop table #datosparaocupacion;

		select	
			dni = ltrim(rtrim(p.dni)),
			rol = case when p.inquilino = 1 then 'inquilino' else 'propietario' end,
			iduf = u.nrouf,
			row_number() over (order by p.dni) as rowid
		into #datosparaocupacion
		from #temppersonas p
		inner join #tempuf u on ltrim(rtrim(p.cvu_cbu)) = ltrim(rtrim(u.cvu_cbu))
		where not exists (
			select 1 from consorcio.ocupacion oc	
			where oc.dni = ltrim(rtrim(p.dni)) and oc.iduf = u.nrouf
		);

		-- procesar cada registro llamando al procedure
		declare @total int = (select count(*) from #datosparaocupacion);
		declare @contador int = 1;

		print 'registros a procesar: ' + cast(@total as varchar);

		while @contador <= @total
		begin
			declare @dni varchar(10), @rol char(11), @iduf int;

			select @dni = dni, @rol = rol, @iduf = iduf
			from #datosparaocupacion	
			where rowid = @contador;

			begin try
				exec consorcio.sp_agrocupacion	
					@rol = @rol,
					@iduf = @iduf,
					@dni = @dni;
				
				set @registrosinsertados = @registrosinsertados + 1;
				print 'ocupación insertada: dni ' + @dni + ' en uf ' + cast(@iduf as varchar) + ' como ' + @rol;
			end try
			begin catch
				set @registrosfallidos = @registrosfallidos + 1;
				print 'error al insertar ocupación para dni ' + @dni + ': ' + error_message();
			end catch

			set @contador = @contador + 1;
		end

		print 'importación de ocupaciones completada.';
		print 'ocupaciones insertadas: ' + cast(@registrosinsertados as varchar);
		print 'ocupaciones fallidas: ' + cast(@registrosfallidos as varchar);


		drop table #temppersonas;
		drop table #tempuf;
		drop table #datosparaocupacion;

	end try
	begin catch
		print 'error durante la importación: ' + error_message();
		if object_id('tempdb..#temppersonas') is not null drop table #temppersonas;
		if object_id('tempdb..#tempuf') is not null drop table #tempuf;
		if object_id('tempdb..#datosparaocupacion') is not null drop table #datosparaocupacion;
		throw;
	end catch
end
go

exec consorcio.importarocupaciones	
	@rutaarchpersonas = 'c:\archivos_para_el_tp\inquilino-propietarios-datos.csv',
	@rutaarchuf = 'c:\archivos_para_el_tp\inquilino-propietarios-uf.csv';

select * from consorcio.Ocupacion

-------------------------------------------------
--											   --
--			       ESQUEMA PAGO        	       --
--											   --
-------------------------------------------------


CREATE OR ALTER PROCEDURE Pago.sp_importarPagosDesdeCSV
    @rutaArchivo NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Iniciando importación de pagos desde: ' + @rutaArchivo;

    BEGIN TRY
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL
            DROP TABLE #PagosTemp;

        -- Crear tabla temporal
        CREATE TABLE #PagosTemp (
            IdPago INT,
            Fecha NVARCHAR(50),
            CVU_CBU NVARCHAR(50) NULL,
            Valor NVARCHAR(100)
        );

        -- Cargar los datos del CSV
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
        BULK INSERT #PagosTemp
        FROM ''' + @rutaArchivo + '''
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
        
        PRINT 'Ejecutando BULK INSERT...';
        EXEC sp_executesql @sql;

        PRINT 'Pagos cargados desde el CSV: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- Agregar columnas para el procesamiento
        ALTER TABLE #PagosTemp 
        ADD ID INT IDENTITY(1,1),
            IdUF INT NULL,
            Importe DECIMAL(12,2) NULL,
            FechaProcesada DATE NULL,
            ValorLimpio NVARCHAR(100) NULL;

        -- LIMPIAR EL VALOR
        UPDATE #PagosTemp 
        SET ValorLimpio = REPLACE(REPLACE(REPLACE(REPLACE(Valor, '$', ''), ' ', ''), ',', '.'), '''', '')
        WHERE Valor IS NOT NULL AND Valor != '';

        -- CONVERTIR IMPORTE
        UPDATE #PagosTemp 
        SET Importe = TRY_CAST(ValorLimpio AS DECIMAL(12,2))
        WHERE ValorLimpio IS NOT NULL AND ValorLimpio != '';

        PRINT 'Importes convertidos: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- Convertir fecha a DATE
        UPDATE #PagosTemp 
        SET FechaProcesada = TRY_CONVERT(DATE, Fecha, 103) -- formato dd/mm/yyyy
        WHERE Fecha IS NOT NULL;

        PRINT 'Fechas convertidas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- ASIGNAR IdUF - DIRECTAMENTE DESDE Persona (que tiene idUF)
        UPDATE #PagosTemp
        SET IdUF = p.idUF
        FROM #PagosTemp pt
        INNER JOIN consorcio.Persona p ON pt.CVU_CBU = p.CVU  -- JOIN directo usando CVU
        WHERE pt.IdUF IS NULL;

        PRINT 'Unidades funcionales asignadas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- VERIFICAR DATOS ANTES DE PROCESAR
        PRINT '=== VERIFICACIÓN DE DATOS ===';
        SELECT 
            COUNT(*) as TotalRegistros,
            SUM(CASE WHEN IdPago IS NOT NULL THEN 1 ELSE 0 END) as ConIdPago,
            SUM(CASE WHEN FechaProcesada IS NOT NULL THEN 1 ELSE 0 END) as ConFecha,
            SUM(CASE WHEN Importe IS NOT NULL AND Importe > 0 THEN 1 ELSE 0 END) as ConImporte,
            SUM(CASE WHEN IdUF IS NOT NULL THEN 1 ELSE 0 END) as ConIdUF
        FROM #PagosTemp;

        -- MOSTRAR EJEMPLOS DE PROBLEMAS
        PRINT '=== REGISTROS CON PROBLEMAS ===';
        SELECT TOP 10 IdPago, Fecha, CVU_CBU, Valor, Importe, IdUF
        FROM #PagosTemp 
        WHERE IdUF IS NULL OR Importe IS NULL OR FechaProcesada IS NULL;

        -- Variables para recorrer la tabla temporal
        DECLARE @id INT = 1, @maxId INT;
        DECLARE 
            @IdPago INT,
            @Fecha DATE,
            @Importe DECIMAL(12,2),
            @CuentaOrigen CHAR(22),
            @IdUF INT;

        SELECT @maxId = MAX(ID) FROM #PagosTemp;

        PRINT 'Procesando ' + CAST(@maxId AS VARCHAR(10)) + ' registros...';

        WHILE @id <= @maxId
        BEGIN
            SELECT
                @IdPago = IdPago,
                @Fecha = FechaProcesada,
                @Importe = Importe,
                @CuentaOrigen = CVU_CBU,
                @IdUF = IdUF
            FROM #PagosTemp WHERE ID = @id;

            -- Solo procesar registros válidos
            IF @IdPago IS NOT NULL AND @Fecha IS NOT NULL AND @Importe IS NOT NULL AND @Importe > 0 AND @IdUF IS NOT NULL
            BEGIN
                -- Llamar al SP que valida e inserta
                BEGIN TRY
                    EXEC Pago.sp_agrPago 
                        @IdPago = @IdPago,
                        @Fecha = @Fecha,
                        @Importe = @Importe,
                        @CuentaOrigen = @CuentaOrigen,
                        @IdUF = @IdUF;

                    PRINT 'Pago insertado - ID: ' + CAST(@IdPago AS VARCHAR(10)) + 
                          ' - Fecha: ' + CONVERT(VARCHAR(10), @Fecha, 103) + 
                          ' - Importe: $' + CAST(@Importe AS VARCHAR(20)) +
                          ' - IdUF: ' + CAST(@IdUF AS VARCHAR(10));
                END TRY
                BEGIN CATCH
                    PRINT ' Error al insertar pago ID ' + CAST(@IdPago AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
                END CATCH;
            END
            ELSE
            BEGIN
                PRINT '⏭Registro omitido - ' +
                      'IdPago: ' + ISNULL(CAST(@IdPago AS VARCHAR(10)), 'NULL') +
                      ', Fecha: ' + ISNULL(CONVERT(VARCHAR(10), @Fecha, 103), 'NULL') +
                      ', Importe: ' + ISNULL(CAST(@Importe AS VARCHAR(20)), 'NULL') +
                      ', IdUF: ' + ISNULL(CAST(@IdUF AS VARCHAR(10)), 'NULL');
            END

            SET @id += 1;
        END;

        -- Estadísticas finales
        DECLARE @totalRegistros INT, @registrosProcesados INT, @registrosOmitidos INT;
        
        SELECT @totalRegistros = COUNT(*) FROM #PagosTemp;
        SELECT @registrosProcesados = COUNT(*) FROM #PagosTemp 
        WHERE IdPago IS NOT NULL AND FechaProcesada IS NOT NULL AND Importe IS NOT NULL AND Importe > 0 AND IdUF IS NOT NULL;
        SET @registrosOmitidos = @totalRegistros - @registrosProcesados;

        PRINT '=== RESUMEN DE IMPORTACIÓN ===';
        PRINT 'Total de registros en CSV: ' + CAST(@totalRegistros AS VARCHAR(10));
        PRINT 'Registros procesados exitosamente: ' + CAST(@registrosProcesados AS VARCHAR(10));
        PRINT 'Registros omitidos: ' + CAST(@registrosOmitidos AS VARCHAR(10));

        DROP TABLE #PagosTemp;

    END TRY
    BEGIN CATCH
        PRINT 'Error durante la importación: ' + ERROR_MESSAGE();
        PRINT 'Detalle del error: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
    END CATCH;
END;
GO
exec pago.sp_importarPagosDesdeCSV @rutaArchivo = 'C:\Archivos_para_el_tp\pagos_consorcios.csv'

select * from Pago.Pago

-------------------------------------------------
--											   --
--			     ESQUEMA EXPENSAS       	   --
--											   --
-------------------------------------------------