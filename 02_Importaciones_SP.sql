-------------------------------------------------
--											   --
--			BASES DE DATOS APLICADA		       --
--											   --
-------------------------------------------------
-- GRUPO: 07                                  --
-- INTEGRANTES:								   --
-- Mendoza, Diego Emanuel			           --
-- Vazquez, Isaac Benjamin                     --
-- Pizarro Dorgan, Fabricio Alejandro          --
-- Piñero, Agustín                             --
-- Nardelli Rosales, Cecilia Anahi             --
-- Comerci Salcedo, Francisco Ivan             --
-------------------------------------------------
-------------------------------------------------
--											   --
--			     IMPORTACIONES      	       --
--											   --
-------------------------------------------------
--PRIMERO DEBEMOS EJECUTAR EL DE CONSORCIOS--
--SE EJECUTAN LOS SIGUIENTE COMANDOS--
--IMPORTANTE!!!!!!!!!!!!!!!!!!!!!!!!!!-
--SE DEBEN INSTALAR LOS DRIVERS NECESARIOS PARA EL OLDB
--https://www.microsoft.com/en-us/download/details.aspx?id=54920
--ASEGURESE DE ESTAR PARADO EN LA BASE DE DATOS DEL TRABAJO

USE Com5600G07
GO
/*
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
GO*/
-------------------------------------------------
--											   --
--			     TABLA DE LOG      	           --
--											   --
-------------------------------------------------
/*
 * report.Sp_LogReporte
 * Registra eventos del sistema en la tabla de logs y retorna 
 * confirmación en formato XML.
 *   - Inserta registros de log en report.logsReportes para auditoría
 *   - Devuelve confirmación estructurada en XML con detalles del log generado
 *   - Soporta tipos INFO, WARN, ERROR para categorización de eventos
 *
 *   EXEC report.Sp_LogReporte 
 *        @SP = 'Sp_ProcesarArchivo',
 *        @Tipo = 'INFO',
 *        @Mensaje = 'Proceso completado',
 *        @RutaArchivo = 'C:\datos\archivo.xlsx'
 *
 * RESULTADO:
 *   - Registro en tabla report.logsReportes
 *   - XML con confirmación y ID del log generado
 */
CREATE OR ALTER PROCEDURE report.Sp_LogReporte
    @SP           SYSNAME,
    @Tipo         VARCHAR(30),
    @Mensaje      NVARCHAR(4000) = NULL,
    @RutaArchivo  NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Guardar en la tabla
    INSERT INTO report.logsReportes(SP, Tipo, Mensaje, RutaArchivo)
    VALUES (@SP, @Tipo, @Mensaje, @RutaArchivo);

    -- Mostrar mensaje de confirmación en XML
    SELECT 
        'OK' AS 'Estado',
        'Log registrado correctamente' AS 'Descripcion',
        @SP AS 'Procedimiento',
        @Tipo AS 'Tipo',
        @Mensaje AS 'Mensaje',
        @RutaArchivo AS 'ArchivoOrigen',
        SCOPE_IDENTITY() AS 'IdLogGenerado'
    FOR XML PATH('Respuesta'), ROOT('LogResultado');

END
GO
-------------------------------------------------
--											   --
--			    TABLA CONSORCIOS      	       --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE ImportarConsorciosDesdeExcel
    @RutaArchivo NVARCHAR(500),
    @NombreHoja NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RegistrosLeidos INT = 0;
    DECLARE @ConsorciosProcesados INT = 0;
    DECLARE @ConsorciosExistentes INT = 0;
    DECLARE @Errores INT = 0;
    DECLARE @MensajeResumen NVARCHAR(4000);
    DECLARE @MensajeError NVARCHAR(4000); -- Variable para mensajes de error

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
        SET @RegistrosLeidos = @@ROWCOUNT;
    END TRY
    BEGIN CATCH
        -- Construir mensaje de error en variable
        SET @MensajeError = 'Error al leer el archivo Excel: ' + ERROR_MESSAGE();
        
        -- Solo log error en lectura
        EXEC report.Sp_LogReporte
            @SP = 'ImportarConsorciosDesdeExcel',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeError,
            @RutaArchivo = @RutaArchivo;
        RETURN;
    END CATCH

    -- Variables para el bucle
    DECLARE @ID INT = 1;
    DECLARE @MaxID INT;
    DECLARE @NombreConsorcio VARCHAR(100);
    DECLARE @Direccion NVARCHAR(200);
    DECLARE @CantUnidades INT;
    DECLARE @SuperficieTotal DECIMAL(10,2);

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

        -- Verificar si el consorcio ya existe
        IF NOT EXISTS (
            SELECT 1 
            FROM consorcio.Consorcio c 
            WHERE c.Direccion = @Direccion 
              AND c.NombreConsorcio = @NombreConsorcio
        )
        BEGIN
            BEGIN TRY
                -- Ejecutar el stored procedure de inserción
                EXEC consorcio.sp_agrConsorcio 
                    @NombreConsorcio,
                    @Direccion,
                    @SuperficieTotal,
                    @CantUnidades,
                    2.00,  -- MoraPrimerVTO
                    5.00;  -- MoraProxVTO

                SET @ConsorciosProcesados = @ConsorciosProcesados + 1;
            END TRY
            BEGIN CATCH
                SET @Errores = @Errores + 1;
                
                -- Construir mensaje de error en variable
                SET @MensajeError = 'Error al insertar consorcio: ' + @NombreConsorcio + ' - ' + ERROR_MESSAGE();
                
                -- Solo log error en inserción
                EXEC report.Sp_LogReporte
                    @SP = 'ImportarConsorciosDesdeExcel',
                    @Tipo = 'ERROR',
                    @Mensaje = @MensajeError,
                    @RutaArchivo = @RutaArchivo;
            END CATCH
        END
        ELSE
        BEGIN
            SET @ConsorciosExistentes = @ConsorciosExistentes + 1;
        END

        SET @ID = @ID + 1;
    END;

    -- Log de resumen final
    SET @MensajeResumen = 'Importación completada. ' +
               'Registros leídos: ' + CAST(@RegistrosLeidos AS VARCHAR(10)) + ', ' +
               'Procesados: ' + CAST(@ConsorciosProcesados AS VARCHAR(10)) + ', ' +
               'Existentes: ' + CAST(@ConsorciosExistentes AS VARCHAR(10)) + ', ' +
               'Errores: ' + CAST(@Errores AS VARCHAR(10));

    EXEC report.Sp_LogReporte
        @SP = 'ImportarConsorciosDesdeExcel',
        @Tipo = 'INFO',
        @Mensaje = @MensajeResumen,
        @RutaArchivo = @RutaArchivo;

    -- Limpiar
    DROP TABLE #TempConsorcios;
END;
GO
---------------------------------------------------------------------
--											                       --
--			 TABLA UNIDAD FUNCIONAL, BAULERA Y COCHERA      	   --
--											                       --
---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.importarunidadesfuncionales
    @rutaarch nvarchar(255)
AS
BEGIN 
    SET NOCOUNT ON;
    
    DECLARE @RegistrosLeidos INT = 0;
    DECLARE @TotalUFs INT = 0;
    DECLARE @TotalBauleras INT = 0;
    DECLARE @TotalCocheras INT = 0;
    DECLARE @ConsorciosNuevos INT = 0;
    DECLARE @MensajeResumen NVARCHAR(4000);
    DECLARE @MensajeError NVARCHAR(4000);
    DECLARE @MensajeAuxiliar NVARCHAR(4000);
    DECLARE @nombrearchivo nvarchar(255);
    
    BEGIN TRY
        -- Obtener nombre del archivo
        SET @nombrearchivo = RIGHT(@rutaarch, CHARINDEX('\', REVERSE(@rutaarch)) - 1);

        -- Log inicio
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarunidadesfuncionales',
            @Tipo = 'INFO',
            @Mensaje = 'Iniciando importación de unidades funcionales',
            @RutaArchivo = @rutaarch;

        -- 1. Crear tabla temporal
        IF OBJECT_ID('tempdb..#ufstemp') IS NOT NULL
            DROP TABLE #ufstemp;

        CREATE TABLE #ufstemp (
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

        -- 2. Importar archivo
        DECLARE @sql nvarchar(max);
        
        SET @sql = N'BULK INSERT #ufstemp FROM ''' + @rutaarch + ''' WITH (
            FIRSTROW = 2,  
            FIELDTERMINATOR = ''\t'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            MAXERRORS = 1000
        )';
        
        EXEC sp_executesql @sql;
        
        SET @RegistrosLeidos = @@ROWCOUNT;

        -- Log lectura exitosa
        SET @MensajeAuxiliar = 'Registros leídos del archivo: ' + CAST(@RegistrosLeidos AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarunidadesfuncionales',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaarch;

        -- 3. Limpiar datos vacíos
        DELETE FROM #ufstemp
        WHERE LTRIM(RTRIM(ISNULL([nombre del consorcio], ''))) = '';

        -- 4. Crear tabla temporal para consorcios nuevos
        IF OBJECT_ID('tempdb..#consorciosnuevos') IS NOT NULL
            DROP TABLE #consorciosnuevos;

        CREATE TABLE #consorciosnuevos (
            nombreconsorcio nvarchar(100)
        );

        -- Insertar consorcios que no existen
        INSERT INTO #consorciosnuevos (nombreconsorcio)
        SELECT DISTINCT LTRIM(RTRIM(t.[nombre del consorcio]))
        FROM #ufstemp t
        WHERE NOT EXISTS (
            SELECT 1 
            FROM consorcio.consorcio c 
            WHERE c.nombreconsorcio = LTRIM(RTRIM(t.[nombre del consorcio]))
        );

        SET @ConsorciosNuevos = @@ROWCOUNT;

        -- 5. Insertar nuevos consorcios
        INSERT INTO consorcio.consorcio (nombreconsorcio, direccion, superficie_total, moraprimervto, moraproxvto)
        SELECT 
            nombreconsorcio,
            'Dirección ' + nombreconsorcio,
            1000.00,
            2.00,
            5.00
        FROM #consorciosnuevos;

        DROP TABLE #consorciosnuevos;

        -- 6. Insertar unidades funcionales
        INSERT INTO consorcio.unidadfuncional (piso, depto, superficie, coeficiente, idconsorcio)
        SELECT 
            LTRIM(RTRIM(t.piso)),
            LTRIM(RTRIM(t.departamento)),
            CASE 
                WHEN ISNUMERIC(t.m2_unidad_funcional) = 1 
                THEN CAST(t.m2_unidad_funcional AS DECIMAL(6,2))
                ELSE 0 
            END AS superficie,
            CASE 
                WHEN ISNUMERIC(REPLACE(t.coeficiente, ',', '.')) = 1 
                THEN CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(5,2))
                ELSE 0 
            END AS coeficiente,
            c.idconsorcio
        FROM #ufstemp t
        INNER JOIN consorcio.consorcio c 
            ON c.nombreconsorcio = LTRIM(RTRIM(t.[nombre del consorcio]))
        WHERE LTRIM(RTRIM(ISNULL(t.piso, ''))) != ''
          AND LTRIM(RTRIM(ISNULL(t.departamento, ''))) != '';

        SET @TotalUFs = @@ROWCOUNT;

        -- 7. Insertar bauleras
        INSERT INTO consorcio.baulera (tamanio, iduf)
        SELECT 
            CASE 
                WHEN ISNUMERIC(t.m2_baulera) = 1 
                THEN CAST(t.m2_baulera AS DECIMAL(10,2))
                ELSE 0 
            END AS tamanio,
            uf.iduf
        FROM #ufstemp t
        INNER JOIN consorcio.consorcio c 
            ON c.nombreconsorcio = LTRIM(RTRIM(t.[nombre del consorcio]))
        INNER JOIN consorcio.unidadfuncional uf 
            ON uf.piso = LTRIM(RTRIM(t.piso)) 
            AND uf.depto = LTRIM(RTRIM(t.departamento))
            AND uf.idconsorcio = c.idconsorcio
        WHERE LTRIM(RTRIM(ISNULL(t.bauleras, ''))) = 'si'
          AND ISNUMERIC(t.m2_baulera) = 1
          AND CAST(t.m2_baulera AS DECIMAL(10,2)) > 0;

        SET @TotalBauleras = @@ROWCOUNT;

        -- 8. Insertar cocheras
        INSERT INTO consorcio.cochera (tamanio, iduf)
        SELECT 
            CASE 
                WHEN ISNUMERIC(t.m2_cochera) = 1 
                THEN CAST(t.m2_cochera AS DECIMAL(10,2))
                ELSE 0 
            END AS tamanio,
            uf.iduf
        FROM #ufstemp t
        INNER JOIN consorcio.consorcio c 
            ON c.nombreconsorcio = LTRIM(RTRIM(t.[nombre del consorcio]))
        INNER JOIN consorcio.unidadfuncional uf 
            ON uf.piso = LTRIM(RTRIM(t.piso)) 
            AND uf.depto = LTRIM(RTRIM(t.departamento))
            AND uf.idconsorcio = c.idconsorcio
        WHERE LTRIM(RTRIM(ISNULL(t.cochera, ''))) = 'si'
          AND ISNUMERIC(t.m2_cochera) = 1
          AND CAST(t.m2_cochera AS DECIMAL(10,2)) > 0;

        SET @TotalCocheras = @@ROWCOUNT;

        -- Log resumen final
        SET @MensajeResumen = 'Importación completada. ' +
                   'Registros leídos: ' + CAST(@RegistrosLeidos AS VARCHAR(10)) + ', ' +
                   'Consorcios nuevos: ' + CAST(@ConsorciosNuevos AS VARCHAR(10)) + ', ' +
                   'UFs insertadas: ' + CAST(@TotalUFs AS VARCHAR(10)) + ', ' +
                   'Bauleras: ' + CAST(@TotalBauleras AS VARCHAR(10)) + ', ' +
                   'Cocheras: ' + CAST(@TotalCocheras AS VARCHAR(10));

        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarunidadesfuncionales',
            @Tipo = 'INFO',
            @Mensaje = @MensajeResumen,
            @RutaArchivo = @rutaarch;

        DROP TABLE #ufstemp;

    END TRY
    BEGIN CATCH
        SET @MensajeError = 'Error durante importación: ' + ERROR_MESSAGE() + ' - Línea: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarunidadesfuncionales',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeError,
            @RutaArchivo = @rutaarch;

        IF OBJECT_ID('tempdb..#ufstemp') IS NOT NULL
            DROP TABLE #ufstemp;
        IF OBJECT_ID('tempdb..#consorciosnuevos') IS NOT NULL
            DROP TABLE #consorciosnuevos;
            
        THROW;
    END CATCH
END
GO
-------------------------------------------------
--											   --
--			    TABLA PERSONAS      	       --
--											   --
-------------------------------------------------

CREATE OR ALTER PROCEDURE consorcio.importarPersonas
    @rutaArchPersonas NVARCHAR(255),
    @rutaArchUF NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @PersonasCargadas INT = 0;
    DECLARE @UFCargadas INT = 0;
    DECLARE @DuplicadosEliminados INT = 0;
    DECLARE @PersonasInsertadas INT = 0;
    DECLARE @MensajeResumen NVARCHAR(4000);
    DECLARE @MensajeError NVARCHAR(4000);
    DECLARE @MensajeAuxiliar NVARCHAR(4000);

BEGIN TRY

    SET @MensajeAuxiliar = 'Iniciando importación desde CSV.';
    EXEC report.Sp_LogReporte @SP='consorcio.importarPersonas',@Tipo='INFO',@Mensaje=@MensajeAuxiliar,@RutaArchivo=@rutaArchPersonas;


    IF OBJECT_ID('tempdb..#tempPersonas') IS NOT NULL DROP TABLE #tempPersonas;

    CREATE TABLE #tempPersonas(
        Nombre NVARCHAR(50),
        Apellido NVARCHAR(50),
        DNI VARCHAR(10),
        Email NVARCHAR(100),
        Telefono NVARCHAR(15),
        CVU_CBU CHAR(22),
        Inquilino INT
    );

    SET @sql = N'
        BULK INSERT #tempPersonas
        FROM ''' + @rutaArchPersonas + '''
        WITH (FIRSTROW=2, FIELDTERMINATOR='';'', ROWTERMINATOR=''\n'', CODEPAGE=''65001'')';
    EXEC sp_executesql @sql;

    SET @PersonasCargadas = @@ROWCOUNT;

    IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL DROP TABLE #tempUF;

    CREATE TABLE #tempUF(
        CVU_CBU CHAR(22),
        NombreConsorcio NVARCHAR(50),
        NroUF INT,
        Piso NVARCHAR(10),
        Departamento NVARCHAR(10)
    );

    SET @sql = N'
        BULK INSERT #tempUF
        FROM ''' + @rutaArchUF + '''
        WITH (FIRSTROW=2, FIELDTERMINATOR=''|'', ROWTERMINATOR=''\n'', CODEPAGE=''65001'')';
    EXEC sp_executesql @sql;

    SET @UFCargadas = @@ROWCOUNT;

    IF OBJECT_ID('tempdb..#personasSinDuplicados') IS NOT NULL DROP TABLE #personasSinDuplicados;

    SELECT
        DNI = LTRIM(RTRIM(DNI)),
        Nombre = LEFT(LTRIM(RTRIM(Nombre)),30),
        Apellido = LEFT(LTRIM(RTRIM(Apellido)),30),
        Email = NULLIF(LEFT(LTRIM(RTRIM(Email)),40),''),
        Telefono = NULLIF(LEFT(LTRIM(RTRIM(Telefono)),15),''),
        CVU_CBU = LTRIM(RTRIM(CVU_CBU)),
        Inquilino,
        ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(DNI)) ORDER BY (SELECT NULL)) AS RowNum
    INTO #personasSinDuplicados
    FROM #tempPersonas;

    DELETE FROM #personasSinDuplicados WHERE RowNum > 1;
    SET @DuplicadosEliminados = @@ROWCOUNT;


    INSERT INTO consorcio.Persona (DNI,Nombre,Apellido,Email,Telefono,CVU,idUF)
    SELECT
        p.DNI,
        p.Nombre,
        p.Apellido,
        p.Email,
        p.Telefono,
        p.CVU_CBU,
        uf.IdUF
    FROM #personasSinDuplicados p
    INNER JOIN #tempUF t ON t.CVU_CBU = p.CVU_CBU
    INNER JOIN consorcio.Consorcio c
        ON c.NombreConsorcio = t.NombreConsorcio
    INNER JOIN consorcio.UnidadFuncional uf
        ON uf.IdConsorcio = c.IdConsorcio
        AND uf.Piso = t.Piso
        AND uf.Depto = t.Departamento
    WHERE NOT EXISTS (
        SELECT 1 FROM consorcio.Persona per WHERE per.DNI = p.DNI
    );

    SET @PersonasInsertadas = @@ROWCOUNT;

    DROP TABLE #tempPersonas;
    DROP TABLE #tempUF;
    DROP TABLE #personasSinDuplicados;

    SET @MensajeResumen =
        'Importación completa. Personas cargadas=' + CAST(@PersonasCargadas AS VARCHAR(10)) +
        ', UF cargadas=' + CAST(@UFCargadas AS VARCHAR(10)) +
        ', Duplicados eliminados=' + CAST(@DuplicadosEliminados AS VARCHAR(10)) +
        ', Personas insertadas=' + CAST(@PersonasInsertadas AS VARCHAR(10));

    EXEC report.Sp_LogReporte @SP='consorcio.importarPersonas',@Tipo='INFO',@Mensaje=@MensajeResumen,@RutaArchivo=@rutaArchPersonas;

END TRY
BEGIN CATCH
    SET @MensajeError = 'Error: ' + ERROR_MESSAGE();
    EXEC report.Sp_LogReporte @SP='consorcio.importarPersonas',@Tipo='ERROR',@Mensaje=@MensajeError,@RutaArchivo=@rutaArchPersonas;

    IF OBJECT_ID('tempdb..#tempPersonas') IS NOT NULL DROP TABLE #tempPersonas;
    IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL DROP TABLE #tempUF;
    IF OBJECT_ID('tempdb..#personasSinDuplicados') IS NOT NULL DROP TABLE #personasSinDuplicados;

    THROW;
END CATCH
END
GO


-------------------------------------------------
--											   --
--			    TABLA OCUPACION      	       --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.importarocupaciones
    @rutaarchpersonas NVARCHAR(255),
    @rutaarchuf NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @RegistrosInsertados INT = 0;
    DECLARE @RegistrosFallidos INT = 0;
    DECLARE @TotalRegistros INT = 0;
    DECLARE @Contador INT = 1;
    DECLARE @MensajeResumen NVARCHAR(4000);
    DECLARE @MensajeError NVARCHAR(4000);
    DECLARE @MensajeAuxiliar NVARCHAR(4000);

    BEGIN TRY
        -- Log inicio
        SET @MensajeAuxiliar = 'Iniciando importación de ocupaciones desde archivos CSV: ' + @rutaarchpersonas + ' y ' + @rutaarchuf;
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarocupaciones',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaarchpersonas;

        -- Cargar datos temporales
        IF OBJECT_ID('tempdb..#temppersonas') IS NOT NULL DROP TABLE #temppersonas;
        IF OBJECT_ID('tempdb..#tempuf') IS NOT NULL DROP TABLE #tempuf;

        CREATE TABLE #temppersonas (
            nombre NVARCHAR(50), apellido NVARCHAR(50), dni VARCHAR(10),
            email NVARCHAR(100), telefono NVARCHAR(15), cvu_cbu CHAR(22), inquilino INT
        );

        CREATE TABLE #tempuf (
            cvu_cbu CHAR(22), nombreconsorcio NVARCHAR(50), nrouf INT,
            piso NVARCHAR(10), departamento NVARCHAR(10)
        );

        SET @sql = N'BULK INSERT #temppersonas FROM ''' + @rutaarchpersonas + ''' WITH (FIRSTROW = 2, FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        SET @sql = N'BULK INSERT #tempuf FROM ''' + @rutaarchuf + ''' WITH (FIRSTROW = 2, FIELDTERMINATOR = ''|'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        -- Crear tabla temporal con los datos procesados
        IF OBJECT_ID('tempdb..#datosparaocupacion') IS NOT NULL
            DROP TABLE #datosparaocupacion;

        SELECT    
            dni = LTRIM(RTRIM(p.dni)),
            rol = CASE WHEN p.inquilino = 1 THEN 'Inquilino' ELSE 'Propietario' END,
            iduf = u.nrouf,
            ROW_NUMBER() OVER (ORDER BY p.dni) AS rowid
        INTO #datosparaocupacion
        FROM #temppersonas p
        INNER JOIN #tempuf u ON LTRIM(RTRIM(p.cvu_cbu)) = LTRIM(RTRIM(u.cvu_cbu))
        WHERE NOT EXISTS (
            SELECT 1 FROM consorcio.ocupacion oc    
            WHERE oc.dni = LTRIM(RTRIM(p.dni)) AND oc.iduf = u.nrouf
        );

        SET @TotalRegistros = (SELECT COUNT(*) FROM #datosparaocupacion);

        -- Log registros a procesar
        SET @MensajeAuxiliar = 'Registros a procesar: ' + CAST(@TotalRegistros AS VARCHAR);
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarocupaciones',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaarchpersonas;

        -- Procesar cada registro llamando al procedure
        WHILE @Contador <= @TotalRegistros
        BEGIN
            DECLARE @dni VARCHAR(10), @rol CHAR(11), @iduf INT;

            SELECT @dni = dni, @rol = rol, @iduf = iduf
            FROM #datosparaocupacion    
            WHERE rowid = @Contador;

            BEGIN TRY
                EXEC consorcio.sp_agrocupacion    
                    @rol = @rol,
                    @iduf = @iduf,
                    @dni = @dni;
                
                SET @RegistrosInsertados = @RegistrosInsertados + 1;
            END TRY
            BEGIN CATCH
                SET @RegistrosFallidos = @RegistrosFallidos + 1;
                
                -- Log error individual
                SET @MensajeError = 'Error al insertar ocupación para DNI ' + @dni + ': ' + ERROR_MESSAGE();
                EXEC report.Sp_LogReporte
                    @SP = 'consorcio.importarocupaciones',
                    @Tipo = 'ERROR',
                    @Mensaje = @MensajeError,
                    @RutaArchivo = @rutaarchpersonas;
            END CATCH

            SET @Contador = @Contador + 1;
        END

        -- Log resumen final
        SET @MensajeResumen = 'Importación de ocupaciones completada. ' +
                   'Ocupaciones insertadas: ' + CAST(@RegistrosInsertados AS VARCHAR(10)) + ', ' +
                   'Ocupaciones fallidas: ' + CAST(@RegistrosFallidos AS VARCHAR(10));

        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarocupaciones',
            @Tipo = 'INFO',
            @Mensaje = @MensajeResumen,
            @RutaArchivo = @rutaarchpersonas;

        -- Limpiar tablas temporales
        DROP TABLE #temppersonas;
        DROP TABLE #tempuf;
        DROP TABLE #datosparaocupacion;

    END TRY
    BEGIN CATCH
        SET @MensajeError = 'Error durante la importación: ' + ERROR_MESSAGE();
        
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarocupaciones',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeError,
            @RutaArchivo = @rutaarchpersonas;

        IF OBJECT_ID('tempdb..#temppersonas') IS NOT NULL DROP TABLE #temppersonas;
        IF OBJECT_ID('tempdb..#tempuf') IS NOT NULL DROP TABLE #tempuf;
        IF OBJECT_ID('tempdb..#datosparaocupacion') IS NOT NULL DROP TABLE #datosparaocupacion;
        
        THROW;
    END CATCH
END
GO
-------------------------------------------------
--											   --
--		   TABLA GASTOS Y EXPENSA       	   --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.Sp_CargarGastosDesdeJson
    @JsonContent NVARCHAR(MAX),
    @Anio INT,
    @DiaVto1 INT, 
    @DiaVto2 INT,
    @RutaExcelProveedores NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Carga desde excel y json';    
    BEGIN TRY
        PRINT 'Cargando proveedores desde excel';
        
        IF OBJECT_ID('tempdb..#ProveedoresTemp') IS NOT NULL DROP TABLE #ProveedoresTemp;
        CREATE TABLE #ProveedoresTemp (
            idConsorcio INT,
            categoria NVARCHAR(100),
            proveedor NVARCHAR(100),
            descripcion NVARCHAR(200),
            nroCuenta NVARCHAR(50)
        );
        
        DECLARE @SqlProveedores NVARCHAR(MAX);
        
        SET @SqlProveedores = 
        'INSERT INTO #ProveedoresTemp (categoria, proveedor, descripcion, nroCuenta, idConsorcio) ' +
        'SELECT ' +
        '    LTRIM(RTRIM(F1)), ' +
        '    LTRIM(RTRIM(F2)), ' +
        '    LTRIM(RTRIM(F3)), ' +
        '    LTRIM(RTRIM(F4)), ' +
        '    c.IdConsorcio ' +
        'FROM OPENROWSET( ' +
        '    ''Microsoft.ACE.OLEDB.16.0'', ' +
        '    ''Excel 12.0;Database=' + @RutaExcelProveedores + ';HDR=NO'', ' +
        '    ''SELECT * FROM [Proveedores$B2:E100]'' ' +
        ') excel ' +
        'INNER JOIN consorcio.Consorcio c ON c.NombreConsorcio = LTRIM(RTRIM(excel.F4)) ' +
        'WHERE LTRIM(RTRIM(F1)) IS NOT NULL ' +
        '  AND LTRIM(RTRIM(F4)) IS NOT NULL';
        
        EXEC sp_executesql @SqlProveedores;
        
        DECLARE @ProveedoresCargados INT = @@ROWCOUNT;
        PRINT 'Proveedores cargados: ' + CAST(@ProveedoresCargados AS VARCHAR);

        -- Log de carga de proveedores
        DECLARE @MensajeProveedores NVARCHAR(500);
        SET @MensajeProveedores = 'Proveedores cargados desde Excel: ' + CAST(@ProveedoresCargados AS VARCHAR(10)) + ' registros';
        
        EXEC report.Sp_LogReporte
            @SP = 'gastos.Sp_CargarGastosDesdeJson',
            @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
            @Mensaje = @MensajeProveedores,
            @RutaArchivo = @RutaExcelProveedores;
        

        PRINT 'Procesando json';
        
        -- staging 
        IF OBJECT_ID('tempdb..#stg_gasto') IS NOT NULL DROP TABLE #stg_gasto;
        CREATE TABLE #stg_gasto (
            consorcio NVARCHAR(200),
            mes_raw NVARCHAR(50),
            mes TINYINT,
            categoria NVARCHAR(100),
            importe_raw NVARCHAR(100),
            importe DECIMAL(18,2)
        );

        -- Insertar datos del Json
        INSERT INTO #stg_gasto (consorcio, mes_raw, categoria, importe_raw)
        SELECT 
            LTRIM(RTRIM(JSON_VALUE([value], '$."Nombre del consorcio"'))) as consorcio,
            LTRIM(RTRIM(JSON_VALUE([value], '$."Mes"'))) as mes_raw,
            v.categoria,
            v.importe_raw
        FROM OPENJSON(@JsonContent)
        CROSS APPLY (VALUES
            ('BANCARIOS', JSON_VALUE([value], '$."BANCARIOS"')),
            ('LIMPIEZA', JSON_VALUE([value], '$."LIMPIEZA"')),
            ('ADMINISTRACION', JSON_VALUE([value], '$."ADMINISTRACION"')),
            ('SEGUROS', JSON_VALUE([value], '$."SEGUROS"')),
            ('GASTOS GENERALES', JSON_VALUE([value], '$."GASTOS GENERALES"')),
            ('SERVICIOS PUBLICOS-AGUA', JSON_VALUE([value], '$."SERVICIOS PUBLICOS-Agua"')),
            ('SERVICIOS PUBLICOS-LUZ', JSON_VALUE([value], '$."SERVICIOS PUBLICOS-Luz"'))
        ) v(categoria, importe_raw)
        WHERE JSON_VALUE([value], '$."Nombre del consorcio"') IS NOT NULL;

 
        UPDATE #stg_gasto SET
            mes = CASE LOWER(mes_raw)
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
                ELSE NULL
            END,
            importe = CASE 
                WHEN importe_raw IS NULL OR importe_raw = '' THEN 0
                ELSE TRY_CAST(REPLACE(REPLACE(REPLACE(importe_raw, '.', ''), ',', '.'), ' ', '') AS DECIMAL(18,2))
            END;

        PRINT 'Registros en staging JSON: ' + CAST(@@ROWCOUNT AS VARCHAR);
        
        --Veo si los consorcios del json coinciden
        IF EXISTS (
            SELECT DISTINCT s.consorcio 
            FROM #stg_gasto s 
            WHERE NOT EXISTS (
                SELECT 1 FROM consorcio.Consorcio c WHERE c.NombreConsorcio = s.consorcio
            )
        )
        BEGIN
            DECLARE @ConsorciosFaltantes NVARCHAR(1000);
            
            SELECT @ConsorciosFaltantes = ISNULL(STRING_AGG(consorcio, ', '), 'Ninguno identificado')
            FROM (SELECT DISTINCT consorcio FROM #stg_gasto s 
                  WHERE NOT EXISTS (SELECT 1 FROM consorcio.Consorcio c WHERE c.NombreConsorcio = s.consorcio)) f;
            
            DECLARE @MensajeErrorConsorcios NVARCHAR(2000);
            SET @MensajeErrorConsorcios = 'Los siguientes consorcios no existen en la base de datos: ' + @ConsorciosFaltantes;
            
            -- Log de error de consorcios faltantes
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'ERROR',
                @Mensaje = @MensajeErrorConsorcios,
                @RutaArchivo = @RutaExcelProveedores;
            
            RAISERROR(@MensajeErrorConsorcios, 16, 1);
            RETURN;
        END

        -- Temp consorcios
        IF OBJECT_ID('tempdb..#cons') IS NOT NULL DROP TABLE #cons;
        SELECT DISTINCT c.IdConsorcio, s.consorcio
        INTO #cons
        FROM #stg_gasto s
        INNER JOIN consorcio.Consorcio c ON c.NombreConsorcio = s.consorcio;

        PRINT 'Consorcios a procesar: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- Totales por consorcio y mes
        IF OBJECT_ID('tempdb..#totales') IS NOT NULL DROP TABLE #totales;
        SELECT 
            c.IdConsorcio,
            s.mes,
            SUM(s.importe) as total,
            DATEFROMPARTS(@Anio, s.mes, 1) as fechaBase,
            EOMONTH(DATEFROMPARTS(@Anio, s.mes, 1)) as finMes
        INTO #totales
        FROM #stg_gasto s
        INNER JOIN #cons c ON c.consorcio = s.consorcio
        WHERE s.importe > 0 AND s.mes BETWEEN 1 AND 12
        GROUP BY c.IdConsorcio, s.mes;

        PRINT 'Totales calculados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- Crear expensas
        DECLARE @ExpensasCreadas INT = 0;
        
        INSERT INTO expensas.Expensa (idConsorcio, fechaGeneracion, fechaVto1, fechaVto2, montoTotal)
        SELECT 
            t.IdConsorcio,
            t.fechaBase as fechaGeneracion,
            CASE WHEN @DiaVto1 <= DAY(t.finMes) 
                THEN DATEFROMPARTS(@Anio, t.mes, @DiaVto1)
                ELSE t.finMes END as fechaVto1,
            CASE WHEN @DiaVto2 <= DAY(t.finMes) 
                THEN DATEFROMPARTS(@Anio, t.mes, @DiaVto2)
                ELSE t.finMes END as fechaVto2,
            CASE 
                WHEN t.total > 99999999.99 THEN 99999999.99
                WHEN t.total < -99999999.99 THEN -99999999.99
                ELSE t.total
            END as montoTotal
        FROM #totales t
        WHERE NOT EXISTS (
            SELECT 1 FROM expensas.Expensa e 
            WHERE e.idConsorcio = t.IdConsorcio 
            AND YEAR(e.fechaGeneracion) = @Anio 
            AND MONTH(e.fechaGeneracion) = t.mes
        );

        SET @ExpensasCreadas = @@ROWCOUNT;

        PRINT 'Expensas creadas: ' + CAST(@ExpensasCreadas AS VARCHAR(10));

        -- Log de creación de expensas
        DECLARE @MensajeExpensas NVARCHAR(500);
        IF @ExpensasCreadas > 0
        BEGIN
            SET @MensajeExpensas = 'Expensas creadas exitosamente: ' + CAST(@ExpensasCreadas AS VARCHAR(10)) + ' registros';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
                @Mensaje = @MensajeExpensas,
                @RutaArchivo = @RutaExcelProveedores;
        END
        ELSE
        BEGIN
            SET @MensajeExpensas = 'No se crearon nuevas expensas (todas ya existían)';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',
                @Mensaje = @MensajeExpensas,
                @RutaArchivo = @RutaExcelProveedores;
        END


        PRINT 'Generando prorrateo para las expensas creadas...';

        -- Tabla temporal para expensas que necesitan prorrateo
        IF OBJECT_ID('tempdb..#ExpensasSinProrrateo') IS NOT NULL DROP TABLE #ExpensasSinProrrateo;
        SELECT 
            e.nroExpensa,
            e.idConsorcio,
            e.montoTotal
        INTO #ExpensasSinProrrateo
        FROM expensas.Expensa e
        INNER JOIN #totales t ON e.idConsorcio = t.IdConsorcio 
            AND YEAR(e.fechaGeneracion) = @Anio 
            AND MONTH(e.fechaGeneracion) = t.mes
        WHERE NOT EXISTS (
            SELECT 1 FROM expensas.Prorrateo p WHERE p.NroExpensa = e.nroExpensa
        );

        PRINT 'Expensas a procesar en prorrateo: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

      
        PRINT 'Verificando cálculo de prorrateo...';

        -- Tabla temporal para verificar cálculos
        IF OBJECT_ID('tempdb..#VerificacionProrrateo') IS NOT NULL DROP TABLE #VerificacionProrrateo;
        SELECT 
            esp.nroExpensa,
            esp.idConsorcio,
            esp.montoTotal as MontoTotalConsorcio,
            uf.idUF,
            uf.Superficie,
            sc.SuperficieTotal,
            (uf.Superficie / sc.SuperficieTotal) * 100 as PorcentajeCalculado,
            esp.montoTotal * (uf.Superficie / sc.SuperficieTotal) as MontoPorUF
        INTO #VerificacionProrrateo
        FROM #ExpensasSinProrrateo esp
        INNER JOIN consorcio.UnidadFuncional uf ON esp.idConsorcio = uf.idConsorcio
        INNER JOIN (
            SELECT 
                idConsorcio,
                SUM(Superficie) as SuperficieTotal
            FROM consorcio.UnidadFuncional 
            WHERE idConsorcio IN (SELECT DISTINCT idConsorcio FROM #ExpensasSinProrrateo)
            GROUP BY idConsorcio
        ) sc ON uf.idConsorcio = sc.idConsorcio;

        DECLARE @ProrrateosGenerados INT = 0;
       
        INSERT INTO expensas.Prorrateo (
            NroExpensa, 
            IdUF, 
            Porcentaje, 
            SaldoAnterior,
            PagosRecibidos,
            InteresMora,
            ExpensaOrdinaria, 
            ExpensaExtraordinaria,
            Total, 
            Deuda
        )
        SELECT 
            vp.nroExpensa,
            vp.idUF,
            vp.PorcentajeCalculado,
            0, -- SaldoAnterior
            0, -- PagosRecibidos
            0, -- InteresMora
            vp.MontoPorUF, -- ExpensaOrdinaria 
            0, -- ExpensaExtraordinaria
            vp.MontoPorUF, -- Total 
            vp.MontoPorUF  -- Deuda
        FROM #VerificacionProrrateo vp;

        SET @ProrrateosGenerados = @@ROWCOUNT;

        PRINT 'Prorrateos generados: ' + CAST(@ProrrateosGenerados AS VARCHAR(10));

        -- Log de prorrateos generados
        IF @ProrrateosGenerados > 0
        BEGIN
            DECLARE @MensajeProrrateos NVARCHAR(500);
            SET @MensajeProrrateos = 'Prorrateos generados exitosamente: ' + CAST(@ProrrateosGenerados AS VARCHAR(10)) + ' registros';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
                @Mensaje = @MensajeProrrateos,
                @RutaArchivo = @RutaExcelProveedores;
        END

        DROP TABLE #VerificacionProrrateo;
        DROP TABLE #ExpensasSinProrrateo;
       
        IF OBJECT_ID('tempdb..#exp') IS NOT NULL DROP TABLE #exp;
        SELECT 
            c.IdConsorcio,
            s.mes,
            e.nroExpensa
        INTO #exp
        FROM #stg_gasto s
        INNER JOIN #cons c ON c.consorcio = s.consorcio
        INNER JOIN expensas.Expensa e ON e.idConsorcio = c.IdConsorcio
            AND YEAR(e.fechaGeneracion) = @Anio 
            AND MONTH(e.fechaGeneracion) = s.mes;

        PRINT 'Expensas encontradas: ' + CAST(@@ROWCOUNT AS VARCHAR);

        PRINT 'Insertando gastos';
        
        -- Insertar gastos
        DECLARE @GastosInsertados INT = 0;
        
        INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
        SELECT 
            e.nroExpensa,
            c.IdConsorcio,
            CASE WHEN s.categoria = 'GASTOS GENERALES' THEN 'Extraordinario' ELSE 'Ordinario' END as tipo,
            s.categoria + ' - ' + s.mes_raw as descripcion,
            DATEFROMPARTS(@Anio, s.mes, 1) as fechaEmision,
            CASE 
                WHEN s.importe > 99999999.99 THEN 99999999.99
                WHEN s.importe < -99999999.99 THEN -99999999.99
                ELSE s.importe
            END as importe
        FROM #stg_gasto s
        INNER JOIN #cons c ON c.consorcio = s.consorcio
        INNER JOIN #exp e ON e.IdConsorcio = c.IdConsorcio AND e.mes = s.mes
        WHERE s.importe > 0;

        SET @GastosInsertados = @@ROWCOUNT;

        PRINT 'Gastos insertados: ' + CAST(@GastosInsertados AS VARCHAR(10));

        -- Log de gastos insertados
        DECLARE @MensajeGastos NVARCHAR(500);
        IF @GastosInsertados > 0
        BEGIN
            SET @MensajeGastos = 'Gastos insertados exitosamente: ' + CAST(@GastosInsertados AS VARCHAR(10)) + ' registros';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
                @Mensaje = @MensajeGastos,
                @RutaArchivo = @RutaExcelProveedores;
        END
        ELSE
        BEGIN
            SET @MensajeGastos = 'No se insertaron gastos (posiblemente no hay importes válidos)';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'WARN',  -- Cambiado de 'WARNING' a 'WARN'
                @Mensaje = @MensajeGastos,
                @RutaArchivo = @RutaExcelProveedores;
        END

        PRINT 'Asignando proveedores';
        
        DECLARE @GastosOrdinariosAsignados INT = 0;
        
        INSERT INTO gastos.Gasto_Ordinario (idGasto, nombreProveedor, categoria, nroFactura)
        SELECT 
            g.idGasto,
            p.proveedor as nombreProveedor,
            p.categoria,
            'FAC-' + CAST(g.idGasto as VARCHAR(20)) as nroFactura
        FROM gastos.Gasto g
        INNER JOIN #ProveedoresTemp p ON p.idConsorcio = g.idConsorcio
            AND (
                (g.descripcion LIKE '%BANCARIOS%' AND p.categoria = 'GASTOS BANCARIOS') OR
                (g.descripcion LIKE '%ADMINISTRACION%' AND p.categoria = 'GASTOS DE ADMINISTRACION') OR
                (g.descripcion LIKE '%SEGUROS%' AND p.categoria = 'SEGUROS') OR
                (g.descripcion LIKE '%LIMPIEZA%' AND p.categoria = 'GASTOS DE LIMPIEZA') OR
                (g.descripcion LIKE '%AGUA%' AND p.categoria = 'SERVICIOS PUBLICOS' AND p.proveedor = 'AYSA') OR
                (g.descripcion LIKE '%LUZ%' AND p.categoria = 'SERVICIOS PUBLICOS' AND p.proveedor = 'EDENOR')
            )
        WHERE g.tipo = 'Ordinario'
            AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Ordinario o WHERE o.idGasto = g.idGasto);

        SET @GastosOrdinariosAsignados = @@ROWCOUNT;

        PRINT 'Gastos ordinarios con proveedores: ' + CAST(@GastosOrdinariosAsignados AS VARCHAR(10));

        -- Log de gastos ordinarios asignados
        IF @GastosOrdinariosAsignados > 0
        BEGIN
            DECLARE @MensajeOrdinarios NVARCHAR(500);
            SET @MensajeOrdinarios = 'Gastos ordinarios asignados con proveedores: ' + CAST(@GastosOrdinariosAsignados AS VARCHAR(10)) + ' registros';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
                @Mensaje = @MensajeOrdinarios,
                @RutaArchivo = @RutaExcelProveedores;
        END

        --gastos extraordinarios
        DECLARE @GastosExtraordinariosAsignados INT = 0;
        
        INSERT INTO gastos.Gasto_Extraordinario (idGasto, cuotaActual, cantCuotas)
        SELECT 
            g.idGasto,
            1 as cuotaActual,
            1 as cantCuotas
        FROM gastos.Gasto g
        WHERE g.tipo = 'Extraordinario'
            AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario e WHERE e.idGasto = g.idGasto);
        
        SET @GastosExtraordinariosAsignados = @@ROWCOUNT;
        
        PRINT 'Gastos extraordinarios: ' + CAST(@GastosExtraordinariosAsignados AS VARCHAR(10));

        -- Log de gastos extraordinarios asignados
        IF @GastosExtraordinariosAsignados > 0
        BEGIN
            DECLARE @MensajeExtraordinarios NVARCHAR(500);
            SET @MensajeExtraordinarios = 'Gastos extraordinarios asignados: ' + CAST(@GastosExtraordinariosAsignados AS VARCHAR(10)) + ' registros';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
                @Mensaje = @MensajeExtraordinarios,
                @RutaArchivo = @RutaExcelProveedores;
        END

        -- totales de gastos por expensa
        IF OBJECT_ID('tempdb..#GastosPorExpensa') IS NOT NULL DROP TABLE #GastosPorExpensa;
        SELECT 
            nroExpensa,
            SUM(CASE WHEN tipo = 'Ordinario' THEN importe ELSE 0 END) as TotalOrdinario,
            SUM(CASE WHEN tipo = 'Extraordinario' THEN importe ELSE 0 END) as TotalExtraordinario,
            SUM(importe) as TotalGeneral
        INTO #GastosPorExpensa
        FROM gastos.Gasto
        WHERE nroExpensa IN (SELECT DISTINCT nroExpensa FROM #exp)
        GROUP BY nroExpensa;

        -- Actualizar prorrateo
        DECLARE @ProrrateosActualizados INT = 0;
        
        UPDATE p
        SET 
            ExpensaOrdinaria = ISNULL(gpe.TotalOrdinario, 0) * (p.Porcentaje / 100),
            ExpensaExtraordinaria = ISNULL(gpe.TotalExtraordinario, 0) * (p.Porcentaje / 100),
            Total = ISNULL(gpe.TotalGeneral, 0) * (p.Porcentaje / 100),
            Deuda = ISNULL(gpe.TotalGeneral, 0) * (p.Porcentaje / 100)
        FROM expensas.Prorrateo p
        INNER JOIN #GastosPorExpensa gpe ON p.NroExpensa = gpe.nroExpensa
        WHERE p.NroExpensa IN (SELECT DISTINCT nroExpensa FROM #exp);

        SET @ProrrateosActualizados = @@ROWCOUNT;

        PRINT 'Prorrateos actualizados con gastos reales: ' + CAST(@ProrrateosActualizados AS VARCHAR(10));

        -- Log de prorrateos actualizados
        IF @ProrrateosActualizados > 0
        BEGIN
            DECLARE @MensajeProrrateosActualizados NVARCHAR(500);
            SET @MensajeProrrateosActualizados = 'Prorrateos actualizados con gastos reales: ' + CAST(@ProrrateosActualizados AS VARCHAR(10)) + ' registros';
            
            EXEC report.Sp_LogReporte
                @SP = 'gastos.Sp_CargarGastosDesdeJson',
                @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
                @Mensaje = @MensajeProrrateosActualizados,
                @RutaArchivo = @RutaExcelProveedores;
        END

        -- Log de resumen final exitoso
        DECLARE @MensajeResumen NVARCHAR(1000);
        SET @MensajeResumen = 'Carga completada exitosamente. ' +
            'Expensas: ' + CAST(@ExpensasCreadas AS VARCHAR(10)) + ', ' +
            'Gastos: ' + CAST(@GastosInsertados AS VARCHAR(10)) + ', ' +
            'Prorrateos: ' + CAST(@ProrrateosGenerados AS VARCHAR(10)) + ', ' +
            'Gastos Ordinarios: ' + CAST(@GastosOrdinariosAsignados AS VARCHAR(10)) + ', ' +
            'Gastos Extraordinarios: ' + CAST(@GastosExtraordinariosAsignados AS VARCHAR(10));

        EXEC report.Sp_LogReporte
            @SP = 'gastos.Sp_CargarGastosDesdeJson',
            @Tipo = 'INFO',  -- Cambiado de 'SUCCESS' a 'INFO'
            @Mensaje = @MensajeResumen,
            @RutaArchivo = @RutaExcelProveedores;

        -- Limpiar temporales
        DROP TABLE #GastosPorExpensa;
        DROP TABLE #exp;
        DROP TABLE #totales;
        DROP TABLE #cons;
        DROP TABLE #stg_gasto;
        DROP TABLE #ProveedoresTemp;
        
    END TRY
    BEGIN CATCH
        DECLARE @MensajeErrorFinal NVARCHAR(4000);
        SET @MensajeErrorFinal = 'ERROR durante la carga: ' + ERROR_MESSAGE();
        
        -- Log de error final
        EXEC report.Sp_LogReporte
            @SP = 'gastos.Sp_CargarGastosDesdeJson',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeErrorFinal,
            @RutaArchivo = @RutaExcelProveedores;
            
        PRINT @MensajeErrorFinal;
        THROW;
    END CATCH
END
GO
--Llama al que carga gastos, expensas y prorrateo (falta que cargue saldo anterior y interes mora)
CREATE OR ALTER PROCEDURE gastos.Sp_CargarGastosDesdeArchivo
    @RutaArchivoJSON NVARCHAR(500),
    @RutaArchivoExcel NVARCHAR(500),
    @Anio INT = 2024,
    @DiaVto1 INT = 10,
    @DiaVto2 INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Iniando carga';
    PRINT 'JSON: ' + @RutaArchivoJSON;
    PRINT 'Excel: ' + @RutaArchivoExcel;
    
    DECLARE @JsonContent NVARCHAR(MAX);
    DECLARE @Sql NVARCHAR(MAX);
    
    -- Leer el archivo JSON
    SET @Sql = N'
    SELECT @JsonContent = BulkColumn
    FROM OPENROWSET(BULK ''' + @RutaArchivoJSON + ''', SINGLE_CLOB) AS j;';
    
    EXEC sp_executesql @Sql, N'@JsonContent NVARCHAR(MAX) OUTPUT', @JsonContent OUTPUT;
    
    IF @JsonContent IS NULL
    BEGIN
        RAISERROR('No se pudo leer el archivo JSON: %s', 16, 1, @RutaArchivoJSON);
        RETURN;
    END
    
    PRINT 'Json leído correctamente';
    
    -- Llamar al procedimiento que integra JSON + Excel
    EXEC gastos.Sp_CargarGastosDesdeJson 
        @JsonContent = @JsonContent,
        @Anio = @Anio,
        @DiaVto1 = @DiaVto1,
        @DiaVto2 = @DiaVto2,
        @RutaExcelProveedores = @RutaArchivoExcel;
        
    PRINT 'Carga completada';
END
GO
-------------------------------------------------
--											   --
--		    TABLA PAGO Y PRORRATEO        	   --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE Pago.sp_importarPagosDesdeCSV
    @rutaArchivo NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- Variables para logs
    DECLARE @PagosCargadosCSV INT = 0;
    DECLARE @PagosProcesadosExitosos INT = 0;
    DECLARE @PagosOmitidos INT = 0;
    DECLARE @ErroresProcesamiento INT = 0;
    DECLARE @ProrrateosCreados INT = 0;
    DECLARE @MensajeLog NVARCHAR(1000);

    BEGIN TRY
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL
            DROP TABLE #PagosTemp;

        CREATE TABLE #PagosTemp (
            IdPago INT,
            Fecha NVARCHAR(50),
            CVU_CBU NVARCHAR(50) NULL,
            Valor NVARCHAR(100)
        );

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
        
        EXEC sp_executesql @sql;

        SET @PagosCargadosCSV = @@ROWCOUNT;
        PRINT 'Pagos cargados desde el CSV: ' + CAST(@PagosCargadosCSV AS VARCHAR(10));

        -- Log de carga desde CSV
        SET @MensajeLog = 'Pagos cargados desde CSV: ' + CAST(@PagosCargadosCSV AS VARCHAR(10)) + ' registros';
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeLog,
            @RutaArchivo = @rutaArchivo;

        ALTER TABLE #PagosTemp 
        ADD ID INT IDENTITY(1,1),
            IdUF INT NULL,
            Importe DECIMAL(12,2) NULL,
            FechaProcesada DATE NULL,
            ValorLimpio NVARCHAR(100) NULL,
            NroExpensa INT NULL;

        
        UPDATE #PagosTemp 
        SET ValorLimpio = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Valor, 
                '$', ''),        
                ' ', ''),        
                '''', ''),       
                '.', ''),        
                ',', '.')
        WHERE Valor IS NOT NULL AND Valor != '';

        PRINT 'Valores limpiados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        UPDATE #PagosTemp 
        SET Importe = TRY_CAST(ValorLimpio AS DECIMAL(12,2))
        WHERE ValorLimpio IS NOT NULL AND ValorLimpio != '';

        PRINT 'Importes convertidos: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        UPDATE #PagosTemp 
        SET FechaProcesada = TRY_CONVERT(DATE, Fecha, 103)
        WHERE Fecha IS NOT NULL;

        
        UPDATE #PagosTemp
        SET IdUF = p.idUF
        FROM #PagosTemp pt
        INNER JOIN consorcio.Persona p ON pt.CVU_CBU = p.CVU
        WHERE pt.IdUF IS NULL;

        PRINT 'Unidades funcionales asignadas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        
        UPDATE #PagosTemp
        SET NroExpensa = pr.NroExpensa
        FROM #PagosTemp pt
        INNER JOIN expensas.Prorrateo pr ON pt.IdUF = pr.IdUF
        INNER JOIN expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
        WHERE pt.FechaProcesada BETWEEN e.fechaGeneracion AND 
              COALESCE(e.fechaVto2, DATEADD(DAY, 30, e.fechaGeneracion))
        AND pt.NroExpensa IS NULL;

        PRINT 'Números de expensa asignados por fecha: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        
        UPDATE #PagosTemp
        SET NroExpensa = (
            SELECT TOP 1 pr.NroExpensa
            FROM expensas.Prorrateo pr
            INNER JOIN expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
            WHERE pr.IdUF = pt.IdUF
            ORDER BY e.fechaGeneracion DESC
        )
        FROM #PagosTemp pt
        WHERE pt.NroExpensa IS NULL AND pt.IdUF IS NOT NULL;

        PRINT 'Números de expensa asignados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- Variables para recorrer la tabla temporal
        DECLARE @id INT = 1, @maxId INT;
        DECLARE 
            @IdPago INT,
            @Fecha DATE,
            @Importe DECIMAL(12,2),
            @CuentaOrigen CHAR(22),
            @IdUF INT,
            @NroExpensa INT,
            @IdPagoInsertado INT;

        SELECT @maxId = MAX(ID) FROM #PagosTemp;

        PRINT 'Procesando ' + CAST(@maxId AS VARCHAR(10)) + ' registros';

        WHILE @id <= @maxId
        BEGIN
            SELECT
                @IdPago = IdPago,
                @Fecha = FechaProcesada,
                @Importe = Importe,
                @CuentaOrigen = CVU_CBU,
                @IdUF = IdUF,
                @NroExpensa = NroExpensa
            FROM #PagosTemp WHERE ID = @id;

        
            IF @IdPago IS NOT NULL AND @Fecha IS NOT NULL AND @Importe IS NOT NULL 
               AND @Importe > 0 AND @IdUF IS NOT NULL AND @NroExpensa IS NOT NULL
            BEGIN
                BEGIN TRY
                    BEGIN TRANSACTION;

                    -- **CORRECCIÓN: OBTENER VALORES ACTUALES DEL PRORRATEO**
                    DECLARE @DeudaActual DECIMAL(12,2);
                    DECLARE @PagosActuales DECIMAL(12,2);
                    DECLARE @TotalExpensa DECIMAL(12,2);

                    -- Obtener los valores actuales del prorrateo
                    SELECT 
                        @PagosActuales = ISNULL(PagosRecibidos, 0),
                        @TotalExpensa = ISNULL(Total, 0),
                        @DeudaActual = ISNULL(Deuda, 0)
                    FROM expensas.Prorrateo 
                    WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

                    -- Si no existe el prorrateo, crear uno básico
                    IF @PagosActuales IS NULL
                    BEGIN
                        SET @PagosActuales = 0;
                        SET @TotalExpensa = @Importe; -- Asumir que el total es igual al pago
                        SET @DeudaActual = @Importe;
                        
                        -- Insertar registro en prorrateo si no existe
                        IF NOT EXISTS (SELECT 1 FROM expensas.Prorrateo WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF)
                        BEGIN
                            INSERT INTO expensas.Prorrateo (NroExpensa, IdUF, Total, PagosRecibidos, Deuda)
                            VALUES (@NroExpensa, @IdUF, @TotalExpensa, 0, @TotalExpensa);
                            
                            SET @ProrrateosCreados = @ProrrateosCreados + 1;
                        END
                    END
                                      
                    -- Insertar el pago
                    INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
                    VALUES (@Fecha, @Importe, @CuentaOrigen, @IdUF, @NroExpensa);

                    SET @IdPagoInsertado = SCOPE_IDENTITY();
                    SET @PagosProcesadosExitosos = @PagosProcesadosExitosos + 1;

                    -- **CORRECCIÓN: CALCULAR NUEVOS VALORES EVITANDO DEUDA NEGATIVA**
                    DECLARE @NuevosPagosRecibidos DECIMAL(12,2) = @PagosActuales + @Importe;
                    
                    -- Asegurar que los pagos recibidos no superen el total
                    IF @NuevosPagosRecibidos > @TotalExpensa
                    BEGIN
                        SET @NuevosPagosRecibidos = @TotalExpensa;
                    END
                    
                    -- Calcular nueva deuda (nunca menor a 0)
                    DECLARE @NuevaDeuda DECIMAL(12,2) = @TotalExpensa - @NuevosPagosRecibidos;
                    IF @NuevaDeuda < 0
                    BEGIN
                        SET @NuevaDeuda = 0;
                    END

                    -- Actualizar el prorrateo con los valores calculados
                    UPDATE expensas.Prorrateo 
                    SET 
                        PagosRecibidos = @NuevosPagosRecibidos,
                        Deuda = @NuevaDeuda
                    WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

                    PRINT 'Pago procesado - ID: ' + CAST(@IdPagoInsertado AS VARCHAR(10)) + 
                          ' - Importe: $' + CAST(@Importe AS VARCHAR(20)) +
                          ' - Pagos anteriores: $' + CAST(@PagosActuales AS VARCHAR(20)) +
                          ' - Pagos nuevos: $' + CAST(@NuevosPagosRecibidos AS VARCHAR(20)) +
                          ' - Deuda nueva: $' + CAST(@NuevaDeuda AS VARCHAR(20)) +
                          ' - IdUF: ' + CAST(@IdUF AS VARCHAR(10)) +
                          ' - Expensa: ' + CAST(@NroExpensa AS VARCHAR(10));

                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 
                        ROLLBACK TRANSACTION;
                    
                    SET @ErroresProcesamiento = @ErroresProcesamiento + 1;
                    
                    PRINT 'Error al procesar el id de pago ' + CAST(@IdPago AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
                END CATCH;
            END
            ELSE
            BEGIN
                SET @PagosOmitidos = @PagosOmitidos + 1;
                
                PRINT 'Registro omitido - ' +
                      'IdPago: ' + ISNULL(CAST(@IdPago AS VARCHAR(10)), 'NULL') +
                      ', Fecha: ' + ISNULL(CONVERT(VARCHAR(10), @Fecha, 103), 'NULL') +
                      ', Importe: ' + ISNULL(CAST(@Importe AS VARCHAR(20)), 'NULL') +
                      ', IdUF: ' + ISNULL(CAST(@IdUF AS VARCHAR(10)), 'NULL') +
                      ', Expensa: ' + ISNULL(CAST(@NroExpensa AS VARCHAR(10)), 'NULL');
            END

            SET @id += 1;
        END;

        DROP TABLE #PagosTemp;
        
        -- Log de resumen final
        SET @MensajeLog = 'Importación de pagos completada. ' +
            'Total CSV: ' + CAST(@PagosCargadosCSV AS VARCHAR(10)) + ', ' +
            'Procesados exitosos: ' + CAST(@PagosProcesadosExitosos AS VARCHAR(10)) + ', ' +
            'Pagos omitidos: ' + CAST(@PagosOmitidos AS VARCHAR(10)) + ', ' +
            'Errores procesamiento: ' + CAST(@ErroresProcesamiento AS VARCHAR(10)) + ', ' +
            'Prorrateos creados: ' + CAST(@ProrrateosCreados AS VARCHAR(10));
        
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeLog,
            @RutaArchivo = @rutaArchivo;

        -- Log de errores si los hay
        IF @ErroresProcesamiento > 0
        BEGIN
            SET @MensajeLog = 'Se produjeron ' + CAST(@ErroresProcesamiento AS VARCHAR(10)) + ' errores durante el procesamiento de pagos';
            EXEC report.Sp_LogReporte
                @SP = 'Pago.sp_importarPagosDesdeCSV',
                @Tipo = 'ERROR',
                @Mensaje = @MensajeLog,
                @RutaArchivo = @rutaArchivo;
        END

        -- Log de pagos omitidos si los hay
        IF @PagosOmitidos > 0
        BEGIN
            SET @MensajeLog = 'Se omitieron ' + CAST(@PagosOmitidos AS VARCHAR(10)) + ' pagos por datos incompletos o inválidos';
            EXEC report.Sp_LogReporte
                @SP = 'Pago.sp_importarPagosDesdeCSV',
                @Tipo = 'WARN',
                @Mensaje = @MensajeLog,
                @RutaArchivo = @rutaArchivo;
        END

        PRINT 'Proceso completado.';

    END TRY
    BEGIN CATCH
        DECLARE @MensajeError NVARCHAR(4000) = 'Error durante la importación: ' + ERROR_MESSAGE();
        
        -- Log de error general
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeError,
            @RutaArchivo = @rutaArchivo;
        
        PRINT @MensajeError;
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE expensas.Sp_ActualizarSaldosAnteriores
    @NroExpensa INT = NULL,
    @ForzarCalculo BIT = 1  -- Nuevo parámetro para testing
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        PRINT '=== ACTUALIZANDO SALDOS ANTERIORES ===';
        
        WITH Calculos AS (
            SELECT 
                p.IdProrrateo,
                p.NroExpensa,
                p.IdUF,
                e.fechaVto1,
                e.fechaVto2,
                -- Calcular saldo anterior (deuda del período anterior de la MISMA UF)
                ISNULL((
                    SELECT TOP 1 p_ant.Deuda 
                    FROM expensas.Prorrateo p_ant
                    INNER JOIN expensas.Expensa e_ant ON p_ant.NroExpensa = e_ant.nroExpensa
                    WHERE p_ant.IdUF = p.IdUF
                      AND e_ant.fechaGeneracion < e.fechaGeneracion
                    ORDER BY e_ant.fechaGeneracion DESC
                ), 0) as SaldoAnteriorCalc
            FROM expensas.Prorrateo p
            INNER JOIN expensas.Expensa e ON p.NroExpensa = e.nroExpensa
            WHERE (@NroExpensa IS NULL OR p.NroExpensa = @NroExpensa)
        )
        UPDATE p
        SET 
            SaldoAnterior = c.SaldoAnteriorCalc,
            InteresMora = 
                CASE 
                    WHEN c.SaldoAnteriorCalc > 0 THEN
                        CASE 
                            WHEN @ForzarCalculo = 1 THEN c.SaldoAnteriorCalc * 0.02  -- Forzar 2% para testing
                            WHEN c.fechaVto2 < GETDATE() THEN c.SaldoAnteriorCalc * 0.05
                            WHEN c.fechaVto1 < GETDATE() THEN c.SaldoAnteriorCalc * 0.02
                            ELSE 0 
                        END
                    ELSE 0 
                END,
            Total = p.ExpensaOrdinaria + p.ExpensaExtraordinaria + 
                   c.SaldoAnteriorCalc + 
                   CASE 
                        WHEN c.SaldoAnteriorCalc > 0 THEN
                            CASE 
                                WHEN @ForzarCalculo = 1 THEN c.SaldoAnteriorCalc * 0.02
                                WHEN c.fechaVto2 < GETDATE() THEN c.SaldoAnteriorCalc * 0.05
                                WHEN c.fechaVto1 < GETDATE() THEN c.SaldoAnteriorCalc * 0.02
                                ELSE 0 
                            END
                        ELSE 0 
                   END,
            Deuda = p.ExpensaOrdinaria + p.ExpensaExtraordinaria + 
                   c.SaldoAnteriorCalc + 
                   CASE 
                        WHEN c.SaldoAnteriorCalc > 0 THEN
                            CASE 
                                WHEN @ForzarCalculo = 1 THEN c.SaldoAnteriorCalc * 0.02
                                WHEN c.fechaVto2 < GETDATE() THEN c.SaldoAnteriorCalc * 0.05
                                WHEN c.fechaVto1 < GETDATE() THEN c.SaldoAnteriorCalc * 0.02
                                ELSE 0 
                            END
                        ELSE 0 
                   END - p.PagosRecibidos
        FROM expensas.Prorrateo p
        INNER JOIN Calculos c ON p.IdProrrateo = c.IdProrrateo;
        
        PRINT 'Actualización completada. Filas afectadas: ' + CAST(@@ROWCOUNT AS VARCHAR);
        
        -- Mostrar resumen
        SELECT 
            'RESULTADOS ACTUALIZADOS' as Info,
            COUNT(*) as Total,
            SUM(CASE WHEN SaldoAnterior > 0 THEN 1 ELSE 0 END) as ConSaldoAnterior,
            SUM(CASE WHEN InteresMora > 0 THEN 1 ELSE 0 END) as ConInteresMora,
            SUM(SaldoAnterior) as TotalSaldoAnterior,
            SUM(InteresMora) as TotalInteresMora
        FROM expensas.Prorrateo
        WHERE (@NroExpensa IS NULL OR NroExpensa = @NroExpensa);
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

