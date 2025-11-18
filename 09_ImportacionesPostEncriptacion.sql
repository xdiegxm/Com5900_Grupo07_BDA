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

    -- 1. Cargar Personas (CSV) a #tempPersonas
    -- (Esto no cambia, leemos texto plano)
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

    -- 2. Cargar Unidades Funcionales (CSV) a #tempUF
    -- (Esto no cambia)
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

    -- 3. Limpiar duplicados de #tempPersonas
    -- (Esto no cambia. La lógica de NULLIF es excelente)
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


    -- 4. INSERTAR en la tabla final consorcio.Persona
    -- ------ INICIO DE LA CORRECCIÓN ------
    INSERT INTO consorcio.Persona (
        DNI, Nombre, Apellido, idUF, -- Columnas estándar
        Email, Telefono, CVU,         -- Columnas ENCRIPTADAS
        Email_Hash, CVU_Hash          -- Columnas HASH
    )
    SELECT
        p.DNI,
        p.Nombre,
        p.Apellido,
        uf.IdUF,

        -- Insertamos los datos ENCRIPTADOS
        -- (La función NULLIF anterior ya se encargó de los vacíos)
        seguridad.EncryptData(p.Email),
        seguridad.EncryptData(p.Telefono),
        seguridad.EncryptData(p.CVU_CBU),

        -- Insertamos los HASHES para búsqueda
        HASHBYTES('SHA2_256', p.Email),
        HASHBYTES('SHA2_256', p.CVU_CBU)
        
    FROM #personasSinDuplicados p
    INNER JOIN #tempUF t ON t.CVU_CBU = p.CVU_CBU
    INNER JOIN consorcio.Consorcio c
        ON c.NombreConsorcio = t.NombreConsorcio
    INNER JOIN consorcio.UnidadFuncional uf
        ON uf.IdConsorcio = c.IdConsorcio
        AND uf.Piso = t.Piso
        AND uf.Depto = t.Departamento
    WHERE NOT EXISTS (
        -- Esta validación sigue siendo correcta, DNI es texto
        SELECT 1 FROM consorcio.Persona per WHERE per.DNI = p.DNI
    );
    -- ------ FIN DE LA CORRECCIÓN ------

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
    IF OBJECT_ID('tempdb..#tempUF') IS NOT null DROP TABLE #tempUF;
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

        SET @MensajeAuxiliar = 'Datos CSV cargados en tablas temporales. Procesando inserción...';
        EXEC report.Sp_LogReporte @SP='consorcio.importarocupaciones',@Tipo='INFO',@Mensaje=@MensajeAuxiliar;

        -- -----------------------------------------------------------------
        -- INICIO DE LA CORRECCIÓN
        -- Se reemplaza el loop (WHILE) por una sola inserción (set-based)
        -- Se busca la IdUF real en lugar de usar u.nrouf
        -- -----------------------------------------------------------------

        INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI)
        SELECT
            -- Columna Rol
            CASE WHEN p.inquilino = 1 THEN 'Inquilino' ELSE 'Propietario' END AS Rol,
            
            -- Columna IdUF (la buscamos correctamente)
            uf.IdUF,
            
            -- Columna DNI
            LTRIM(RTRIM(p.dni)) AS DNI
        FROM
            #temppersonas p
        -- Unimos los CSVs por CVU (en texto plano desde el CSV)
        INNER JOIN #tempuf t
            ON LTRIM(RTRIM(p.cvu_cbu)) = LTRIM(RTRIM(t.cvu_cbu))
        -- Buscamos el IdConsorcio real
        INNER JOIN consorcio.Consorcio c
            ON c.NombreConsorcio = t.nombreconsorcio
        -- Buscamos el IdUF real (usando los datos del CSV de UF)
        INNER JOIN consorcio.UnidadFuncional uf
            ON uf.IdConsorcio = c.IdConsorcio
            AND uf.Piso = t.piso
            AND uf.Depto = t.departamento
        WHERE
            -- Asegurarnos que la persona exista en la tabla Persona (Integridad de FK)
            EXISTS (SELECT 1 FROM consorcio.Persona per WHERE per.DNI = LTRIM(RTRIM(p.dni)))
            
            -- Evitar insertar duplicados que ya existan en Ocupacion
            AND NOT EXISTS (
                SELECT 1 FROM consorcio.Ocupacion oc
                WHERE oc.DNI = LTRIM(RTRIM(p.dni)) AND oc.IdUF = uf.IdUF
            );

        SET @RegistrosInsertados = @@ROWCOUNT;
        -- -----------------------------------------------------------------
        -- FIN DE LA CORRECCIÓN
        -- -----------------------------------------------------------------

        -- Log resumen final
        SET @MensajeResumen = 'Importación de ocupaciones completada. ' +
                      'Ocupaciones insertadas: ' + CAST(@RegistrosInsertados AS VARCHAR(10));

        EXEC report.Sp_LogReporte
            @SP = 'consorcio.importarocupaciones',
            @Tipo = 'INFO',
            @Mensaje = @MensajeResumen,
            @RutaArchivo = @rutaarchpersonas;

        -- Limpiar tablas temporales
        DROP TABLE #temppersonas;
        DROP TABLE #tempuf;

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
        
        THROW;
    END CATCH
END
GO

USE Com5600G07;
GO

-------------------------------------------------
--											   --
--			    TABLA DE PAGOS         	       --
--											   --
-------------------------------------------------
/*Búsqueda de IdUF: El script original busca la IdUF en consorcio.Persona uniendo por CVU. Ahora debemos comparar el hash del CVU del CSV con la columna CVU_Hash de la tabla Persona.
Inserción en Pago.Pago: El script inserta el CVU como texto plano en la columna CuentaOrigen. 
Ahora debemos insertar 
    la versión encriptada (seguridad.EncryptData)  
    la versión hasheada (HASHBYTES) en las columnas 
        CuentaOrigen 
        CuentaOrigen_Hash.*/
USE Com5600G07;
GO

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

        SET @MensajeLog = 'Pagos cargados desde CSV: ' + CAST(@PagosCargadosCSV AS VARCHAR(10)) + ' registros';
        EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'INFO', @Mensaje = @MensajeLog, @RutaArchivo = @rutaArchivo;

        ALTER TABLE #PagosTemp 
        ADD ID INT IDENTITY(1,1),
            IdUF INT NULL,
            Importe DECIMAL(12,2) NULL,
            FechaProcesada DATE NULL,
            ValorLimpio NVARCHAR(100) NULL,
            NroExpensa INT NULL,
            Procesado BIT DEFAULT 0,
            CVU_Limpio VARCHAR(22) NULL, -- CAMBIADO A VARCHAR PARA HASHBYTES
            EsValido BIT DEFAULT 0;

        -- Limpieza y conversión
        UPDATE #PagosTemp 
        SET 
            ValorLimpio = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Valor, 
                '$', ''),   
                ' ', ''),   
                '''', ''),   
                '.', ''),   
                ',', '.'),
            CVU_Limpio = LTRIM(RTRIM(CONVERT(VARCHAR(22), CVU_CBU))) -- CONVERTIR A VARCHAR
        WHERE Valor IS NOT NULL OR CVU_CBU IS NOT NULL;

        PRINT 'Valores limpiados (incl. CVU): ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        UPDATE #PagosTemp 
        SET Importe = TRY_CAST(ValorLimpio AS DECIMAL(12,2))
        WHERE ValorLimpio IS NOT NULL AND ValorLimpio != '';
        PRINT 'Importes convertidos: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        UPDATE #PagosTemp 
        SET FechaProcesada = TRY_CONVERT(DATE, Fecha, 103)
        WHERE Fecha IS NOT NULL;

        -- **DEBUG: Ver qué datos tenemos**
        PRINT '=== VERIFICANDO DATOS ===';
        
        -- Ver cuántos tienen CVU limpio
        SELECT 
            'CVU Status' as Tipo,
            COUNT(*) as Total,
            SUM(CASE WHEN CVU_Limpio IS NOT NULL THEN 1 ELSE 0 END) as ConCVULimpio,
            SUM(CASE WHEN CVU_Limpio IS NULL THEN 1 ELSE 0 END) as SinCVULimpio
        FROM #PagosTemp;

        -- Ver algunos ejemplos de CVUs
        SELECT TOP 5 ID, CVU_CBU, CVU_Limpio
        FROM #PagosTemp 
        WHERE CVU_Limpio IS NOT NULL;

        -- Asignar IdUF usando HASH (CON CONVERT)
        PRINT 'Asignando Unidades Funcionales por HASH de CVU...';
        UPDATE #PagosTemp
        SET IdUF = p.idUF
        FROM #PagosTemp pt
        INNER JOIN consorcio.Persona p 
            ON p.CVU_Hash = HASHBYTES('SHA2_256', pt.CVU_Limpio)
        WHERE pt.IdUF IS NULL
          AND pt.CVU_Limpio IS NOT NULL;

        PRINT 'Unidades funcionales asignadas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- **DEBUG: Ver si se asignaron IdUF**
        SELECT 
            'IdUF Status' as Tipo,
            COUNT(*) as Total,
            SUM(CASE WHEN IdUF IS NOT NULL THEN 1 ELSE 0 END) as ConIdUF,
            SUM(CASE WHEN IdUF IS NULL THEN 1 ELSE 0 END) as SinIdUF
        FROM #PagosTemp;

        -- Si no se asignaron IdUF, mostrar por qué
        IF NOT EXISTS (SELECT 1 FROM #PagosTemp WHERE IdUF IS NOT NULL)
        BEGIN
            PRINT '=== PROBLEMA: No se asignaron IdUF ===';
            
            -- Verificar si hay personas en la tabla
            SELECT 'Personas en BD' as Tipo, COUNT(*) as TotalPersonas FROM consorcio.Persona;
            
            -- Verificar si los CVUs del CSV existen en Persona
            SELECT 
                'CVU Match Status' as Tipo,
                COUNT(*) as TotalCVUs,
                SUM(CASE WHEN EXISTS (
                    SELECT 1 FROM consorcio.Persona p 
                    WHERE p.CVU_Hash = HASHBYTES('SHA2_256', pt.CVU_Limpio)
                ) THEN 1 ELSE 0 END) as CVUsEncontrados,
                SUM(CASE WHEN NOT EXISTS (
                    SELECT 1 FROM consorcio.Persona p 
                    WHERE p.CVU_Hash = HASHBYTES('SHA2_256', pt.CVU_Limpio)
                ) THEN 1 ELSE 0 END) as CVUsNoEncontrados
            FROM #PagosTemp pt
            WHERE pt.CVU_Limpio IS NOT NULL;
        END

        -- Solo continuar si hay registros válidos
        IF EXISTS (SELECT 1 FROM #PagosTemp WHERE IdUF IS NOT NULL)
        BEGIN
            -- Asignar NroExpensa
            UPDATE #PagosTemp
            SET NroExpensa = (
                SELECT TOP 1 pr.NroExpensa
                FROM expensas.Prorrateo pr
                INNER JOIN expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
                WHERE pr.IdUF = pt.IdUF
                    AND pr.Deuda > 0 
                    AND e.fechaGeneracion <= pt.FechaProcesada 
                ORDER BY e.fechaGeneracion ASC 
            )
            FROM #PagosTemp pt
            WHERE pt.NroExpensa IS NULL AND pt.IdUF IS NOT NULL;
            PRINT 'Números de expensa asignados por deuda pendiente: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

            UPDATE #PagosTemp
            SET NroExpensa = (
                SELECT TOP 1 pr.NroExpensa
                FROM expensas.Prorrateo pr
                INNER JOIN expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
                WHERE pr.IdUF = pt.IdUF
                    AND pt.FechaProcesada BETWEEN e.fechaGeneracion AND 
                        COALESCE(e.fechaVto2, DATEADD(DAY, 30, e.fechaGeneracion))
                ORDER BY e.fechaGeneracion DESC
            )
            FROM #PagosTemp pt
            WHERE pt.NroExpensa IS NULL AND pt.IdUF IS NOT NULL;
            PRINT 'Números de expensa asignados por fecha: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

            -- Marcar registros válidos
            UPDATE #PagosTemp
            SET EsValido = 1
            WHERE IdPago IS NOT NULL 
                AND FechaProcesada IS NOT NULL 
                AND Importe IS NOT NULL 
                AND Importe > 0 
                AND IdUF IS NOT NULL 
                AND NroExpensa IS NOT NULL
                AND CVU_Limpio IS NOT NULL
                AND EXISTS (
                    SELECT 1 FROM expensas.Prorrateo 
                    WHERE NroExpensa = #PagosTemp.NroExpensa 
                    AND IdUF = #PagosTemp.IdUF
                );

            -- **PROCESAR PAGOS EN CONJUNTO**
            PRINT 'Procesando pagos válidos...';

            BEGIN TRANSACTION;

            -- Insertar pagos válidos (SOLO CON HASH)
            INSERT INTO Pago.Pago (
                Fecha, 
                Importe, 
                IdUF, 
                NroExpensa,
                CuentaOrigen_Hash
            )
            SELECT 
                FechaProcesada,
                Importe,
                IdUF,
                NroExpensa,
                HASHBYTES('SHA2_256', CVU_Limpio)
            FROM #PagosTemp
            WHERE EsValido = 1;

            SET @PagosProcesadosExitosos = @@ROWCOUNT;
            PRINT 'Pagos insertados: ' + CAST(@PagosProcesadosExitosos AS VARCHAR(10));

            -- **ACTUALIZAR PRORRATEOS EN CONJUNTO**
            IF @PagosProcesadosExitosos > 0
            BEGIN
                PRINT 'Actualizando prorrateos...';

                -- Crear tabla temporal con los pagos agrupados
                IF OBJECT_ID('tempdb..#PagosAgrupados') IS NOT NULL DROP TABLE #PagosAgrupados;
                SELECT 
                    pt.NroExpensa,
                    pt.IdUF,
                    SUM(pt.Importe) as TotalPagado
                INTO #PagosAgrupados
                FROM #PagosTemp pt
                WHERE pt.EsValido = 1
                GROUP BY pt.NroExpensa, pt.IdUF;

                -- Actualizar prorrateos
                UPDATE pr
                SET 
                    PagosRecibidos = ISNULL(pr.PagosRecibidos, 0) + pa.TotalPagado,
                    Deuda = CASE 
                        WHEN (pr.Total - (ISNULL(pr.PagosRecibidos, 0) + pa.TotalPagado)) < 0 THEN 0
                        ELSE pr.Total - (ISNULL(pr.PagosRecibidos, 0) + pa.TotalPagado)
                    END
                FROM expensas.Prorrateo pr
                INNER JOIN #PagosAgrupados pa ON pr.NroExpensa = pa.NroExpensa AND pr.IdUF = pa.IdUF;

                PRINT 'Prorrateos actualizados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
            END

            COMMIT TRANSACTION;
        END
        ELSE
        BEGIN
            PRINT '=== NO SE PROCESARON PAGOS: No hay unidades funcionales asignadas ===';
        END

        -- Calcular estadísticas finales
        SELECT @PagosOmitidos = COUNT(*)
        FROM #PagosTemp
        WHERE EsValido = 0;

        -- Limpiar tablas temporales
        IF OBJECT_ID('tempdb..#PagosAgrupados') IS NOT NULL DROP TABLE #PagosAgrupados;
        DROP TABLE #PagosTemp;

        -- Logs finales
        SET @MensajeLog = 'Importación de pagos completada. ' +
            'Total CSV: ' + CAST(@PagosCargadosCSV AS VARCHAR(10)) + ', ' +
            'Procesados exitosos: ' + CAST(@PagosProcesadosExitosos AS VARCHAR(10)) + ', ' +
            'Pagos omitidos: ' + CAST(@PagosOmitidos AS VARCHAR(10));
        
        EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'INFO', @Mensaje = @MensajeLog, @RutaArchivo = @rutaArchivo;

        IF @PagosOmitidos > 0
        BEGIN
            SET @MensajeLog = 'Se omitieron ' + CAST(@PagosOmitidos AS VARCHAR(10)) + ' pagos por datos incompletos o inválidos';
            EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'WARN', @Mensaje = @MensajeLog, @RutaArchivo = @rutaArchivo;
        END

        PRINT 'Proceso completado.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;
            
        DECLARE @MensajeError NVARCHAR(4000) = 'Error durante la importación: ' + ERROR_MESSAGE();
        EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'ERROR', @Mensaje = @MensajeError, @RutaArchivo = @rutaArchivo;
        PRINT @MensajeError;
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL DROP TABLE #PagosTemp;
        IF OBJECT_ID('tempdb..#PagosAgrupados') IS NOT NULL DROP TABLE #PagosAgrupados;
    END CATCH;
END;
Go
