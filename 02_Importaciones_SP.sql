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
        -- Log inicio
        SET @MensajeAuxiliar = 'Iniciando importación desde archivos CSV: ' + @rutaArchPersonas + ' y ' + @rutaArchUF;
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchPersonas;

        -- Crear tabla temporal para personas
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

        -- Cargar datos de personas
        SET @sql = N'BULK INSERT #tempPersonas FROM ''' + @rutaArchPersonas + ''' 
        WITH (FIRSTROW = 2, FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        SET @PersonasCargadas = @@ROWCOUNT;

        -- Log carga de personas
        SET @MensajeAuxiliar = 'Datos de personas cargados: ' + CAST(@PersonasCargadas AS VARCHAR);
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchPersonas;

        -- Crear tabla temporal para UF
        IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL
            DROP TABLE #tempUF;

        CREATE TABLE #tempUF (
            CVU_CBU CHAR(22),
            NombreConsorcio NVARCHAR(50),
            NroUF INT,
            Piso NVARCHAR(10),
            Departamento NVARCHAR(10)
        );

        -- Cargar datos de UF
        SET @sql = N'BULK INSERT #tempUF FROM ''' + @rutaArchUF + ''' 
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ''|'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        SET @UFCargadas = @@ROWCOUNT;

        -- Log carga de UF
        SET @MensajeAuxiliar = 'Datos de UF cargados: ' + CAST(@UFCargadas AS VARCHAR);
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchUF;

        -- Eliminar duplicados
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

        SET @DuplicadosEliminados = @@ROWCOUNT;

        -- Log eliminación de duplicados
        SET @MensajeAuxiliar = 'Duplicados eliminados del archivo: ' + CAST(@DuplicadosEliminados AS VARCHAR);
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchPersonas;

        -- Insertar datos en tabla Persona
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

        SET @PersonasInsertadas = @@ROWCOUNT;

        -- Log inserción de personas
        SET @MensajeAuxiliar = 'Personas insertadas: ' + CAST(@PersonasInsertadas AS VARCHAR);
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchPersonas;

        -- Limpiar tablas temporales
        DROP TABLE #tempPersonas;
        DROP TABLE #tempUF;
        DROP TABLE #personasSinDuplicados;

        -- Log resumen final
        SET @MensajeResumen = 'Importación completada exitosamente. ' +
                   'Personas cargadas: ' + CAST(@PersonasCargadas AS VARCHAR(10)) + ', ' +
                   'UF cargadas: ' + CAST(@UFCargadas AS VARCHAR(10)) + ', ' +
                   'Duplicados eliminados: ' + CAST(@DuplicadosEliminados AS VARCHAR(10)) + ', ' +
                   'Personas insertadas: ' + CAST(@PersonasInsertadas AS VARCHAR(10));

        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'INFO',
            @Mensaje = @MensajeResumen,
            @RutaArchivo = @rutaArchPersonas;

    END TRY
    BEGIN CATCH
        SET @MensajeError = 'Error durante la importación: ' + ERROR_MESSAGE();
        
        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarPersonas',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeError,
            @RutaArchivo = @rutaArchPersonas;

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
-- A PARTIR DE ACA, (ACTUALIZACION 08/11/2025 18:15hs), NO QUIERO TOCAR NADA CON EL LOG HASTA PODER CARGAR BIEN LAS TABLAS








-------------------------------------------------
--											   --
--			     ESQUEMA GASTOS       	       --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_importarGastosMensuales
    @RutaArchivoJSON NVARCHAR(MAX),
    @RutaArchivoXLSX NVARCHAR(MAX),
    @HojaProveedores NVARCHAR(100),
    @NroExpensa INT,
    @TipoExpensa CHAR(1) = 'O'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    DECLARE @Contador INT = 1, @TotalRows INT;
    DECLARE @NombreConsorcio VARCHAR(100), @Mes VARCHAR(20), @IdConsorcio INT;
    DECLARE @IdGO INT, @IdLimpieza INT;
    DECLARE @Importe DECIMAL(12,2), @NroFactura VARCHAR(15);
    DECLARE @Proveedor VARCHAR(100), @DatoProveedor VARCHAR(100);
    DECLARE @DescripcionGasto VARCHAR(100);

    BEGIN TRY
        -- ===================================================================
        -- PASO 1: Cargar el XLSX 
        -- ===================================================================
        -- Limpieza preventiva
        IF OBJECT_ID('tempdb..##RawProveedores') IS NOT NULL DROP TABLE ##RawProveedores;
        IF OBJECT_ID('tempdb..#TempProveedores') IS NOT NULL DROP TABLE #TempProveedores;

        -- 1.a. Intentamos leer con HDR=YES. 
        -- Si la Fila 1 es ",,,,", el driver podría asignar nombres F1, F2, F3... automáticamente.
        -- Usamos SELECT * INTO ##Global para que agarre lo que encuentre.
        DECLARE @sqlXLSX NVARCHAR(MAX) = N'
        SELECT *
        INTO ##RawProveedores
        FROM OPENROWSET(
            ''Microsoft.ACE.OLEDB.16.0'', 
            ''Excel 12.0 Xml;HDR=YES;IMEX=1;Database=' + REPLACE(@RutaArchivoXLSX, '''', '''''') + ''', 
            ''SELECT * FROM [' + @HojaProveedores + '$]''
        )';
        
        PRINT 'Intentando leer archivo XLSX (con extensión .csv)...';
        EXEC sp_executesql @sqlXLSX;
        
        -- Intentamos una selección genérica basada en la estructura probable que vimos antes.
        -- Si F1 falla, probá reemplazar F1, F2... con los nombres reales si te da error de columna.
        SELECT 
            -- Casteamos todo a VARCHAR para evitar problemas de tipos
            COALESCE(CAST(F2 AS VARCHAR(100)), '') AS TipoGasto,       -- Col B
            COALESCE(CAST(F3 AS VARCHAR(100)), '') AS Detalle,         -- Col C
            COALESCE(CAST(F4 AS VARCHAR(100)), '') AS DatoProveedor,   -- Col D
            COALESCE(CAST(F5 AS VARCHAR(100)), '') AS NombreConsorcio  -- Col E
        INTO #TempProveedores
        FROM ##RawProveedores
        WHERE F5 IS NOT NULL 
          AND CAST(F5 AS VARCHAR(100)) <> 'Nombre del consorcio';

        DROP TABLE ##RawProveedores;
        PRINT 'Proveedores cargados. Registros válidos: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- ===================================================================
        -- PASO 2: Cargar JSON 
        -- ===================================================================
        IF OBJECT_ID('tempdb..#TempJSON') IS NOT NULL DROP TABLE #TempJSON;
        DECLARE @JsonData NVARCHAR(MAX);
        DECLARE @sqlJson NVARCHAR(MAX) = N'
        SELECT @JsonContentOUT = BulkColumn
        FROM OPENROWSET (BULK ''' + REPLACE(@RutaArchivoJSON, '''', '''''') + ''', SINGLE_CLOB) as j';
        EXEC sp_executesql @sqlJson, N'@JsonContentOUT NVARCHAR(MAX) OUTPUT', @JsonContentOUT = @JsonData OUTPUT;

        SELECT * INTO #TempJSON FROM OPENJSON(@JsonData) WITH (
            [Nombre del consorcio] VARCHAR(100), Mes VARCHAR(20), BANCARIOS VARCHAR(50),
            LIMPIEZA VARCHAR(50), ADMINISTRACION VARCHAR(50), SEGUROS VARCHAR(50),
            [GASTOS GENERALES] VARCHAR(50), [SERVICIOS PUBLICOS-Agua] VARCHAR(50),
            [SERVICIOS PUBLICOS-Luz] VARCHAR(50)
        );
        ALTER TABLE #TempJSON ADD ID INT IDENTITY(1,1);
        SELECT @TotalRows = COUNT(*) FROM #TempJSON;

        -- ===================================================================
        -- PASO 3: Procesar Gastos
        -- ===================================================================
        WHILE @Contador <= @TotalRows
        BEGIN
            SELECT @NombreConsorcio = LTRIM(RTRIM([Nombre del consorcio])), @Mes = LTRIM(RTRIM(Mes)) 
            FROM #TempJSON WHERE ID = @Contador;
            SELECT @IdConsorcio = IdConsorcio FROM consorcio.Consorcio WHERE NombreConsorcio = @NombreConsorcio;

            IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE IdConsorcio=@IdConsorcio AND NroExpensa=@NroExpensa AND Tipo=@TipoExpensa)
            BEGIN
                SET @Contador = @Contador + 1; CONTINUE;
            END
            PRINT 'Procesando: ' + @NombreConsorcio;

            -- (A) GASTOS BANCARIOS

            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT BANCARIOS FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                SELECT TOP 1 @DatoProveedor = DatoProveedor FROM #TempProveedores WHERE NombreConsorcio = @NombreConsorcio AND TipoGasto LIKE '%BANCARIOS%';
                SET @NroFactura = 'NC-BANC-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion='Gastos Bancarios', @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                EXEC gastos.sp_agrMantenimiento @IdGO=@IdGO, @Tipo=@TipoExpensa, @Importe=@Importe, @CuentaBancaria=@DatoProveedor;
            END

            -- (B) ADMINISTRACION

            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT ADMINISTRACION FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                SET @NroFactura = 'F-ADM-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion='Honorarios Administracion', @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                EXEC gastos.sp_agrHonorarios @NroFactura=@NroFactura, @IdGO=@IdGO, @Tipo=@TipoExpensa, @Importe=@Importe;
            END

            -- (C) LIMPIEZA

            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT LIMPIEZA FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                SELECT TOP 1 @Proveedor = DatoProveedor FROM #TempProveedores WHERE NombreConsorcio = @NombreConsorcio AND TipoGasto LIKE '%LIMPIEZA%';
                SET @NroFactura = 'F-LIMP-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                SET @DescripcionGasto = 'Servicio Limpieza (' + ISNULL(@Proveedor, '?') + ')';
                EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion=@DescripcionGasto, @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                EXEC @IdLimpieza = gastos.sp_agrLimpieza @IdGO=@IdGO, @Tipo=@TipoExpensa, @Importe=@Importe;
                EXEC Externos.sp_agrEmpresa @IdLimpieza=@IdLimpieza, @IdGO=@IdGO, @nroFactura=@NroFactura, @ImpFactura=@Importe;
            END

            -- (D) SEGUROS

            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT SEGUROS FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                SELECT TOP 1 @Proveedor = DatoProveedor FROM #TempProveedores WHERE NombreConsorcio = @NombreConsorcio AND TipoGasto LIKE 'SEGUROS%';
                SET @NroFactura = 'POL-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                SET @DescripcionGasto = 'Seguro (' + ISNULL(@Proveedor, '?') + ')';
                EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion=@DescripcionGasto, @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                EXEC gastos.sp_agrSeguros @NroFactura=@NroFactura, @IdGO=@IdGO, @Tipo=@TipoExpensa, @NombreEmpresa=@Proveedor, @Importe=@Importe;
            END

            -- (E) GENERALES

            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT [GASTOS GENERALES] FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                 SET @NroFactura = 'F-GEN-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                 EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion='Gastos Generales Varios', @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                 EXEC gastos.sp_agrGenerales @NroFactura=@NroFactura, @IdGO=@IdGO, @Tipo=@TipoExpensa, @TipoGasto='Varios', @NombreEmpresa='Proveedores Varios', @Importe=@Importe;
            END

            -- (F) SERVICIOS

            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT [SERVICIOS PUBLICOS-Agua] FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                SELECT TOP 1 @Proveedor = 'AYSA', @DatoProveedor = DatoProveedor FROM #TempProveedores WHERE NombreConsorcio = @NombreConsorcio AND Detalle LIKE '%AYSA%';
                SET @NroFactura = 'F-AGUA-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion='Servicio Agua', @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                EXEC gastos.sp_agrGenerales @NroFactura=@NroFactura, @IdGO=@IdGO, @Tipo=@TipoExpensa, @TipoGasto='Servicio', @NombreEmpresa=@Proveedor, @Importe=@Importe;
            END
            SET @Importe = TRY_CAST(REPLACE(REPLACE((SELECT [SERVICIOS PUBLICOS-Luz] FROM #TempJSON WHERE ID = @Contador), '.', ''), ',', '.') AS DECIMAL(12,2));
            IF @Importe > 0
            BEGIN
                SELECT TOP 1 @Proveedor = 'EDENOR', @DatoProveedor = DatoProveedor FROM #TempProveedores WHERE NombreConsorcio = @NombreConsorcio AND Detalle LIKE '%EDENOR%';
                SET @NroFactura = 'F-LUZ-' + @Mes + '-' + CAST(@IdConsorcio AS VARCHAR);
                EXEC @IdGO = gastos.sp_agrGastoOrdinario @Tipo=@TipoExpensa, @Descripcion='Servicio Luz', @Importe=@Importe, @NroFactura=@NroFactura, @NroExpensa=@NroExpensa;
                EXEC gastos.sp_agrGenerales @NroFactura=@NroFactura, @IdGO=@IdGO, @Tipo=@TipoExpensa, @TipoGasto='Servicio Luz', @NombreEmpresa=@Proveedor, @Importe=@Importe;
            END

            SET @Contador = @Contador + 1;
        END

        COMMIT TRANSACTION;
        PRINT '=== Importación FINALIZADA con éxito ===';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        -- Si falla, intentamos limpiar la global
        IF OBJECT_ID('tempdb..##RawProveedores') IS NOT NULL DROP TABLE ##RawProveedores;
        PRINT 'ERROR GRAVE: ' + ERROR_MESSAGE();
        THROW;

    END CATCH

END
GO


CREATE OR ALTER PROCEDURE importacion.Sp_CargarGastosDesdeJson
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
        
        PRINT 'Proveedores cargados: ' + CAST(@@ROWCOUNT AS VARCHAR);
        

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
            SELECT @ConsorciosFaltantes = STRING_AGG(consorcio, ', ')
            FROM (SELECT DISTINCT consorcio FROM #stg_gasto s 
                  WHERE NOT EXISTS (SELECT 1 FROM consorcio.Consorcio c WHERE c.NombreConsorcio = s.consorcio)) f;
            
            RAISERROR('Los siguientes consorcios no existen en la base de datos: %s', 16, 1, @ConsorciosFaltantes);
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

        PRINT 'Expensas creadas: ' + CAST(@@ROWCOUNT AS VARCHAR);


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

        PRINT 'Prorrateos generados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

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

        PRINT 'Gastos insertados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        PRINT 'Asignando proveedores';
        
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

        PRINT 'Gastos ordinarios con proveedores: ' + CAST(@@ROWCOUNT AS VARCHAR);

        --gastos extraordinarios
        INSERT INTO gastos.Gasto_Extraordinario (idGasto, cuotaActual, cantCuotas)
        SELECT 
            g.idGasto,
            1 as cuotaActual,
            1 as cantCuotas
        FROM gastos.Gasto g
        WHERE g.tipo = 'Extraordinario'
            AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario e WHERE e.idGasto = g.idGasto);
        
        PRINT 'Gastos extraordinarios: ' + CAST(@@ROWCOUNT AS VARCHAR);

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
        UPDATE p
        SET 
            ExpensaOrdinaria = ISNULL(gpe.TotalOrdinario, 0) * (p.Porcentaje / 100),
            ExpensaExtraordinaria = ISNULL(gpe.TotalExtraordinario, 0) * (p.Porcentaje / 100),
            Total = ISNULL(gpe.TotalGeneral, 0) * (p.Porcentaje / 100),
            Deuda = ISNULL(gpe.TotalGeneral, 0) * (p.Porcentaje / 100)
        FROM expensas.Prorrateo p
        INNER JOIN #GastosPorExpensa gpe ON p.NroExpensa = gpe.nroExpensa
        WHERE p.NroExpensa IN (SELECT DISTINCT nroExpensa FROM #exp);

        PRINT 'Prorrateos actualizados con gastos reales: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- Limpiar temporales
        DROP TABLE #GastosPorExpensa;
        DROP TABLE #exp;
        DROP TABLE #totales;
        DROP TABLE #cons;
        DROP TABLE #stg_gasto;
        DROP TABLE #ProveedoresTemp;
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
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
    EXEC importacion.Sp_CargarGastosDesdeJson 
        @JsonContent = @JsonContent,
        @Anio = @Anio,
        @DiaVto1 = @DiaVto1,
        @DiaVto2 = @DiaVto2,
        @RutaExcelProveedores = @RutaArchivoExcel;
        
    PRINT 'Carga completada';
END
GO


--pagos
--hay que agregarle lo del reporteLog
CREATE OR ALTER PROCEDURE Pago.sp_importarPagosDesdeCSV
    @rutaArchivo NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

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

        PRINT 'Pagos cargados desde el CSV: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

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
                        END
                    END
                                      
                    -- Insertar el pago
                    INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
                    VALUES (@Fecha, @Importe, @CuentaOrigen, @IdUF, @NroExpensa);

                    SET @IdPagoInsertado = SCOPE_IDENTITY();

                    -- **CORRECCIÓN: CALCULAR NUEVOS VALORES**
                    DECLARE @NuevosPagosRecibidos DECIMAL(12,2) = @PagosActuales + @Importe;
                    DECLARE @NuevaDeuda DECIMAL(12,2) = @TotalExpensa - @NuevosPagosRecibidos;

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
                    
                    PRINT 'Error al procesar el id de pago ' + CAST(@IdPago AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
                END CATCH;
            END
            ELSE
            BEGIN
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
        PRINT 'Proceso completado.';

    END TRY
    BEGIN CATCH
        PRINT 'Error durante la importación: ' + ERROR_MESSAGE();
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
    END CATCH;
END;
GO

  

-------------------------------------------------
--											   --
--			     ESQUEMA EXPENSAS       	   --
--											   --
-------------------------------------------------
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

    DECLARE @MensajeResumen NVARCHAR(4000);
    DECLARE @MensajeError NVARCHAR(4000);
    DECLARE @MensajeAuxiliar NVARCHAR(4000);
    DECLARE @PagosCargados INT = 0;
    DECLARE @ValoresLimpiados INT = 0;
    DECLARE @ImportesConvertidos INT = 0;
    DECLARE @UFAsignadas INT = 0;
    DECLARE @ExpensasAsignadasFecha INT = 0;
    DECLARE @ExpensasAsignadas INT = 0;
    DECLARE @PagosProcesados INT = 0;
    DECLARE @PagosOmitidos INT = 0;
    DECLARE @ErroresProcesamiento INT = 0;

    BEGIN TRY
        -- Log inicio
        SET @MensajeAuxiliar = 'Iniciando importación de pagos desde CSV: ' + @rutaArchivo;
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL
            DROP TABLE #PagosTemp;

        CREATE TABLE #PagosTemp (
            IdPago VARCHAR(50),
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
            MAXERRORS = 1000
        );';
        
        EXEC sp_executesql @sql;

        SET @PagosCargados = @@ROWCOUNT;

        -- Log carga de pagos
        SET @MensajeAuxiliar = 'Pagos cargados desde el CSV: ' + CAST(@PagosCargados AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Si no hay registros, terminar
        IF @PagosCargados = 0
        BEGIN
            SET @MensajeError = 'No se cargaron registros del archivo CSV';
            EXEC report.Sp_LogReporte
                @SP = 'Pago.sp_importarPagosDesdeCSV',
                @Tipo = 'ERROR',
                @Mensaje = @MensajeError,
                @RutaArchivo = @rutaArchivo;
            RETURN;
        END;

        ALTER TABLE #PagosTemp 
        ADD ID INT IDENTITY(1,1),
            IdUF INT NULL,
            Importe DECIMAL(12,2) NULL,
            FechaProcesada DATE NULL,
            ValorLimpio NVARCHAR(100) NULL,
            NroExpensa INT NULL;

        -- Limpiar valores
        UPDATE #PagosTemp 
        SET ValorLimpio = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Valor, 
                '$', ''),        
                ' ', ''),        
                '''', ''),       
                '.', ''),        
                ',', '.')
        WHERE Valor IS NOT NULL AND Valor != '';

        SET @ValoresLimpiados = @@ROWCOUNT;

        -- Log valores limpiados
        SET @MensajeAuxiliar = 'Valores limpiados: ' + CAST(@ValoresLimpiados AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Convertir importes
        UPDATE #PagosTemp 
        SET Importe = TRY_CAST(ValorLimpio AS DECIMAL(12,2))
        WHERE ValorLimpio IS NOT NULL AND ValorLimpio != '';

        SET @ImportesConvertidos = @@ROWCOUNT;

        -- Log importes convertidos
        SET @MensajeAuxiliar = 'Importes convertidos: ' + CAST(@ImportesConvertidos AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Procesar fechas
        UPDATE #PagosTemp 
        SET FechaProcesada = TRY_CONVERT(DATE, Fecha, 103)
        WHERE Fecha IS NOT NULL;

        -- Log fechas procesadas
        DECLARE @FechasProcesadas INT = (SELECT COUNT(*) FROM #PagosTemp WHERE FechaProcesada IS NOT NULL);
        SET @MensajeAuxiliar = 'Fechas procesadas correctamente: ' + CAST(@FechasProcesadas AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Asignar unidades funcionales (limpiar CVU_CBU primero)
        UPDATE #PagosTemp
        SET CVU_CBU = LTRIM(RTRIM(CVU_CBU))
        WHERE CVU_CBU IS NOT NULL;

        UPDATE #PagosTemp
        SET IdUF = p.idUF
        FROM #PagosTemp pt
        INNER JOIN consorcio.Persona p ON pt.CVU_CBU = p.CVU
        WHERE pt.IdUF IS NULL;

        SET @UFAsignadas = @@ROWCOUNT;

        -- Log UF asignadas
        SET @MensajeAuxiliar = 'Unidades funcionales asignadas: ' + CAST(@UFAsignadas AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Log registros sin UF
        DECLARE @SinUF INT = (SELECT COUNT(*) FROM #PagosTemp WHERE IdUF IS NULL);
        IF @SinUF > 0
        BEGIN
            SET @MensajeAuxiliar = 'Registros sin UF asignada: ' + CAST(@SinUF AS VARCHAR(10)) + 
                                  '. Ejemplo CVU: ' + ISNULL((SELECT TOP 1 CVU_CBU FROM #PagosTemp WHERE IdUF IS NULL), 'N/A');
            EXEC report.Sp_LogReporte
                @SP = 'Pago.sp_importarPagosDesdeCSV',
                @Tipo = 'WARN',
                @Mensaje = @MensajeAuxiliar,
                @RutaArchivo = @rutaArchivo;
        END;

        -- Asignar números de expensa por fecha
        UPDATE #PagosTemp
        SET NroExpensa = pr.NroExpensa
        FROM #PagosTemp pt
        INNER JOIN expensas.Prorrateo pr ON pt.IdUF = pr.IdUF
        INNER JOIN expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
        WHERE pt.FechaProcesada BETWEEN e.fechaGeneracion AND 
              COALESCE(e.fechaVto2, DATEADD(DAY, 30, e.fechaGeneracion))
        AND pt.NroExpensa IS NULL;

        SET @ExpensasAsignadasFecha = @@ROWCOUNT;

        -- Log expensas asignadas por fecha
        SET @MensajeAuxiliar = 'Números de expensa asignados por fecha: ' + CAST(@ExpensasAsignadasFecha AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Asignar números de expensa restantes (última expensa)
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

        SET @ExpensasAsignadas = @@ROWCOUNT;

        -- Log expensas asignadas
        SET @MensajeAuxiliar = 'Números de expensa asignados restantes: ' + CAST(@ExpensasAsignadas AS VARCHAR(10));
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

        -- Log registros sin expensa
        DECLARE @SinExpensa INT = (SELECT COUNT(*) FROM #PagosTemp WHERE NroExpensa IS NULL AND IdUF IS NOT NULL);
        IF @SinExpensa > 0
        BEGIN
            SET @MensajeAuxiliar = 'Registros con UF pero sin expensa asignada: ' + CAST(@SinExpensa AS VARCHAR(10));
            EXEC report.Sp_LogReporte
                @SP = 'Pago.sp_importarPagosDesdeCSV',
                @Tipo = 'WARN',
                @Mensaje = @MensajeAuxiliar,
                @RutaArchivo = @rutaArchivo;
        END;

        -- Variables para recorrer la tabla temporal
        DECLARE @id INT = 1, @maxId INT;
        DECLARE 
            @IdPago VARCHAR(50),
            @Fecha DATE,
            @Importe DECIMAL(12,2),
            @CuentaOrigen CHAR(22),
            @IdUF INT,
            @NroExpensa INT;

        SELECT @maxId = MAX(ID) FROM #PagosTemp;

        -- Log inicio de procesamiento
        SET @MensajeAuxiliar = 'Procesando ' + CAST(@maxId AS VARCHAR(10)) + ' registros';
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeAuxiliar,
            @RutaArchivo = @rutaArchivo;

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

            IF @Fecha IS NOT NULL AND @Importe IS NOT NULL 
               AND @Importe > 0 AND @IdUF IS NOT NULL AND @NroExpensa IS NOT NULL
            BEGIN
                BEGIN TRY
                    BEGIN TRANSACTION;

                    -- Insertar pago
                    INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
                    VALUES (@Fecha, @Importe, @CuentaOrigen, @IdUF, @NroExpensa);

                    -- Actualizar prorrateo
                    UPDATE expensas.Prorrateo 
                    SET PagosRecibidos = PagosRecibidos + @Importe,
                        Deuda = Total - (PagosRecibidos + @Importe)
                    WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

                    SET @PagosProcesados = @PagosProcesados + 1;

                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 
                        ROLLBACK TRANSACTION;
                    
                    SET @ErroresProcesamiento = @ErroresProcesamiento + 1;
                    
                    -- Log error individual
                    SET @MensajeError = 'Error al procesar registro ' + CAST(@id AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
                    EXEC report.Sp_LogReporte
                        @SP = 'Pago.sp_importarPagosDesdeCSV',
                        @Tipo = 'ERROR',
                        @Mensaje = @MensajeError,
                        @RutaArchivo = @rutaArchivo;
                END CATCH;
            END
            ELSE
            BEGIN
                SET @PagosOmitidos = @PagosOmitidos + 1;
                
                -- Log detalle del registro omitido (solo los primeros 5 para no saturar)
                IF @PagosOmitidos <= 5
                BEGIN
                    SET @MensajeAuxiliar = 'Registro omitido ID ' + CAST(@id AS VARCHAR(10)) + 
                                          ' - Fecha: ' + ISNULL(CONVERT(VARCHAR(10), @Fecha, 103), 'NULL') +
                                          ', Importe: ' + ISNULL(CAST(@Importe AS VARCHAR(20)), 'NULL') +
                                          ', IdUF: ' + ISNULL(CAST(@IdUF AS VARCHAR(10)), 'NULL') +
                                          ', Expensa: ' + ISNULL(CAST(@NroExpensa AS VARCHAR(10)), 'NULL');
                    EXEC report.Sp_LogReporte
                        @SP = 'Pago.sp_importarPagosDesdeCSV',
                        @Tipo = 'WARN',
                        @Mensaje = @MensajeAuxiliar,
                        @RutaArchivo = @rutaArchivo;
                END
            END

            SET @id += 1;
        END;

        DROP TABLE #PagosTemp;

        -- Log resumen final
        SET @MensajeResumen = 'Proceso completado. ' +
                   'Pagos cargados: ' + CAST(@PagosCargados AS VARCHAR(10)) + ', ' +
                   'Importes convertidos: ' + CAST(@ImportesConvertidos AS VARCHAR(10)) + ', ' +
                   'UF asignadas: ' + CAST(@UFAsignadas AS VARCHAR(10)) + ', ' +
                   'Expensas asignadas: ' + CAST((@ExpensasAsignadasFecha + @ExpensasAsignadas) AS VARCHAR(10)) + ', ' +
                   'Pagos procesados: ' + CAST(@PagosProcesados AS VARCHAR(10)) + ', ' +
                   'Pagos omitidos: ' + CAST(@PagosOmitidos AS VARCHAR(10)) + ', ' +
                   'Errores procesamiento: ' + CAST(@ErroresProcesamiento AS VARCHAR(10));

        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeResumen,
            @RutaArchivo = @rutaArchivo;

    END TRY
    BEGIN CATCH
        SET @MensajeError = 'Error durante la importación: ' + ERROR_MESSAGE();
        
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'ERROR',
            @Mensaje = @MensajeError,
            @RutaArchivo = @rutaArchivo;

        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
            
        THROW;
    END CATCH;
END;
GO


--cuando ejecuto esto me da un bucle infinito, fijense q se rompe cuando le ponen los report

--SP para llenar la parte de saldo anterior e intereses por mora de la tabla prorrateo
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
