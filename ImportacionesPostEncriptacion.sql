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
            CVU_CBU NVARCHAR(50) NULL, -- CVU como texto desde el CSV
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
            -- ==== INICIO CORRECCIÓN 1: Añadir columna para CVU limpio ====
            CVU_Limpio CHAR(22) NULL;

        -- Limpiar y convertir valores (AHORA INCLUYE EL CVU)
        UPDATE #PagosTemp 
        SET 
            ValorLimpio = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Valor, 
                '$', ''),   
                ' ', ''),   
                '''', ''),   
                '.', ''),   
                ',', '.'),
            -- Limpiamos el CVU de cualquier espacio extra del CSV
            CVU_Limpio = LTRIM(RTRIM(CVU_CBU))
        WHERE Valor IS NOT NULL OR CVU_CBU IS NOT NULL;
        -- ==== FIN CORRECCIÓN 1 ====

        PRINT 'Valores limpiados (incl. CVU): ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        UPDATE #PagosTemp 
        SET Importe = TRY_CAST(ValorLimpio AS DECIMAL(12,2))
        WHERE ValorLimpio IS NOT NULL AND ValorLimpio != '';
        PRINT 'Importes convertidos: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        UPDATE #PagosTemp 
        SET FechaProcesada = TRY_CONVERT(DATE, Fecha, 103)
        WHERE Fecha IS NOT NULL;

        -- ==== INICIO CORRECCIÓN 2: Usar el CVU limpio para el HASH ====
        PRINT 'Asignando Unidades Funcionales por HASH de CVU...';
        UPDATE #PagosTemp
        SET IdUF = p.idUF
        FROM #PagosTemp pt
        INNER JOIN consorcio.Persona p 
            -- Comparamos el HASH del CVU *limpio* con el HASH de la tabla Persona
            ON p.CVU_Hash = HASHBYTES('SHA2_256', pt.CVU_Limpio)
        WHERE pt.IdUF IS NULL
          AND pt.CVU_Limpio IS NOT NULL;
        -- ==== FIN CORRECCIÓN 2 ====

        PRINT 'Unidades funcionales asignadas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        -- ... (La lógica para buscar NroExpensa no cambia) ...
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

        -- ... (La lógica de marcar no procesados no cambia) ...
        UPDATE #PagosTemp
        SET Procesado = 0
        WHERE NroExpensa IS NOT NULL AND IdUF IS NOT NULL
            AND NOT EXISTS (
                SELECT 1 FROM expensas.Prorrateo 
                WHERE NroExpensa = #PagosTemp.NroExpensa 
                AND IdUF = #PagosTemp.IdUF
            );

        -- Variables para recorrer la tabla temporal
        DECLARE @id INT = 1, @maxId INT;
        DECLARE 
            @IdPago INT,
            @Fecha DATE,
            @Importe DECIMAL(12,2),
            @CuentaOrigen CHAR(22), -- <-- Usamos CHAR(22) para el CVU limpio
            @IdUF INT,
            @NroExpensa INT,
            @IdPagoInsertado INT;

        SELECT @maxId = MAX(ID) FROM #PagosTemp;
        PRINT 'Procesando ' + CAST(ISNULL(@maxId, 0) AS VARCHAR(10)) + ' registros';

        WHILE @id <= @maxId
        BEGIN
            SELECT
                @IdPago = IdPago,
                @Fecha = FechaProcesada,
                @Importe = Importe,
                -- ==== INICIO CORRECCIÓN 3: Usar el CVU limpio ====
                @CuentaOrigen = CVU_Limpio, -- Leemos el CVU limpio
                -- ==== FIN CORRECCIÓN 3 ====
                @IdUF = IdUF,
                @NroExpensa = NroExpensa
            FROM #PagosTemp WHERE ID = @id;

            -- Verificar que existe el prorrateo Y el CVU no es nulo
            IF @IdPago IS NOT NULL AND @Fecha IS NOT NULL AND @Importe IS NOT NULL 
               AND @Importe > 0 AND @IdUF IS NOT NULL AND @NroExpensa IS NOT NULL
               AND @CuentaOrigen IS NOT NULL -- Verificación agregada
               AND EXISTS (SELECT 1 FROM expensas.Prorrateo 
                           WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF)
            BEGIN
                BEGIN TRY
                    BEGIN TRANSACTION;

                    -- ... (La lógica de obtener valores de Prorrateo no cambia) ...
                    DECLARE @DeudaActual DECIMAL(12,2);
                    DECLARE @PagosActuales DECIMAL(12,2);
                    DECLARE @TotalExpensa DECIMAL(12,2);
                    DECLARE @SaldoAnterior DECIMAL(12,2);
                    DECLARE @InteresMora DECIMAL(12,2);
                    DECLARE @ExpensaOrdinaria DECIMAL(12,2);
                    DECLARE @ExpensaExtraordinaria DECIMAL(12,2);

                    SELECT 
                        @PagosActuales = ISNULL(PagosRecibidos, 0),
                        @TotalExpensa = ISNULL(Total, 0),
                        @DeudaActual = ISNULL(Deuda, 0),
                        @SaldoAnterior = ISNULL(SaldoAnterior, 0),
                        @InteresMora = ISNULL(InteresMora, 0),
                        @ExpensaOrdinaria = ISNULL(ExpensaOrdinaria, 0),
                        @ExpensaExtraordinaria = ISNULL(ExpensaExtraordinaria, 0)
                    FROM expensas.Prorrateo 
                    WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

                    -- Insertar el pago con ENCRIPTACIÓN y HASH (usando la variable @CuentaOrigen limpia)
                    INSERT INTO Pago.Pago (
                        Fecha, Importe, IdUF, NroExpensa,
                        CuentaOrigen,       -- Columna Encriptada
                        CuentaOrigen_Hash   -- Columna Hash
                    )
                    VALUES (
                        @Fecha, @Importe, @IdUF, @NroExpensa,
                        seguridad.EncryptData(@CuentaOrigen), -- Encriptamos
                        HASHBYTES('SHA2_256', @CuentaOrigen)  -- Hasheamos
                    );

                    SET @IdPagoInsertado = SCOPE_IDENTITY();
                    SET @PagosProcesadosExitosos = @PagosProcesadosExitosos + 1;

                    -- ... (La lógica de cálculo y actualización de Prorrateo no cambia) ...
                    DECLARE @NuevosPagosRecibidos DECIMAL(12,2) = @PagosActuales + @Importe;
                    DECLARE @TotalReal DECIMAL(12,2) = @ExpensaOrdinaria + @ExpensaExtraordinaria + 
                                                       @SaldoAnterior + @InteresMora;
                    IF @NuevosPagosRecibidos > @TotalReal
                    BEGIN
                        SET @NuevosPagosRecibidos = @TotalReal;
                    END
                    
                    DECLARE @NuevaDeuda DECIMAL(12,2) = @TotalReal - @NuevosPagosRecibidos;
                    IF @NuevaDeuda < 0
                    BEGIN
                        SET @NuevaDeuda = 0;
                    END

                    UPDATE expensas.Prorrateo 
                    SET 
                        PagosRecibidos = @NuevosPagosRecibidos,
                        Deuda = @NuevaDeuda
                    WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

                    UPDATE #PagosTemp SET Procesado = 1 WHERE ID = @id;

                    PRINT 'Pago procesado - ID: ' + CAST(@IdPagoInsertado AS VARCHAR(10)) + 
                          ' - Importe: $' + CAST(@Importe AS VARCHAR(20)) +
                          ' - IdUF: ' + CAST(@IdUF AS VARCHAR(10)) +
                          ' - Expensa: ' + CAST(@NroExpensa AS VARCHAR(10));

                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 
                        ROLLBACK TRANSACTION;
                    
                    SET @ErroresProcesamiento = @ErroresProcesamiento + 1;
                    
                    PRINT 'Error al procesar el id de pago ' + ISNULL(CAST(@IdPago AS VARCHAR(10)), 'N/A') + ': ' + ERROR_MESSAGE();
                    
                    DECLARE @MensajeErrorDetalle NVARCHAR(1000);
                    SET @MensajeErrorDetalle = 'Error procesando pago ID ' + ISNULL(CAST(@IdPago AS VARCHAR(10)), 'N/A') + 
                                               ': ' + ERROR_MESSAGE();
                    EXEC report.Sp_LogReporte
                        @SP = 'Pago.sp_importarPagosDesdeCSV',
                        @Tipo = 'ERROR',
                        @Mensaje = @MensajeErrorDetalle,
                        @RutaArchivo = @rutaArchivo;
                END CATCH;
            END
            ELSE
            BEGIN
                SET @PagosOmitidos = @PagosOmitidos + 1;             
            END

            SET @id += 1;
        END;

        -- ... (La lógica de actualizar saldos posteriores no cambia) ...
        PRINT 'Actualizando saldos anteriores después de procesar pagos...';
        DECLARE @ExpensasAfectadas TABLE (NroExpensa INT);

        INSERT INTO @ExpensasAfectadas (NroExpensa)
        SELECT DISTINCT NroExpensa 
        FROM #PagosTemp 
        WHERE Procesado = 1 AND NroExpensa IS NOT NULL;

        DECLARE @ExpensaActual INT;
        DECLARE cursorExpensas CURSOR FOR SELECT NroExpensa FROM @ExpensasAfectadas;
        OPEN cursorExpensas;
        FETCH NEXT FROM cursorExpensas INTO @ExpensaActual;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT 'Actualizando saldos e intereses para expensa: ' + CAST(@ExpensaActual AS VARCHAR(10));
            
            EXEC expensas.Sp_ActualizarSaldosAnteriores 
                @NroExpensa = @ExpensaActual,
                @CalcularIntereses = 1;
            
            FETCH NEXT FROM cursorExpensas INTO @ExpensaActual;
        END

        CLOSE cursorExpensas;
        DEALLOCATE cursorExpensas;

        DROP TABLE #PagosTemp;
        
        -- ... (La lógica de logs finales no cambia) ...
        SET @MensajeLog = 'Importación de pagos completada. ' +
            'Total CSV: ' + CAST(@PagosCargadosCSV AS VARCHAR(10)) + ', ' +
            'Procesados exitosos: ' + CAST(@PagosProcesadosExitosos AS VARCHAR(10)) + ', ' +
            'Pagos omitidos: ' + CAST(@PagosOmitidos AS VARCHAR(10)) + ', ' +
            'Errores procesamiento: ' + CAST(@ErroresProcesamiento AS VARCHAR(10));
        
        EXEC report.Sp_LogReporte
            @SP = 'Pago.sp_importarPagosDesdeCSV',
            @Tipo = 'INFO',
            @Mensaje = @MensajeLog,
            @RutaArchivo = @rutaArchivo;

        IF @ErroresProcesamiento > 0
        BEGIN
            SET @MensajeLog = 'Se produjeron ' + CAST(@ErroresProcesamiento AS VARCHAR(10)) + ' errores durante el procesamiento de pagos';
            EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'ERROR', @Mensaje = @MensajeLog, @RutaArchivo = @rutaArchivo;
        END

        IF @PagosOmitidos > 0
        BEGIN
            SET @MensajeLog = 'Se omitieron ' + CAST(@PagosOmitidos AS VARCHAR(10)) + ' pagos por datos incompletos o inválidos';
            EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'WARN', @Mensaje = @MensajeLog, @RutaArchivo = @rutaArchivo;
        END

        PRINT 'Proceso completado.';

    END TRY
    BEGIN CATCH
        DECLARE @MensajeError NVARCHAR(4000) = 'Error durante la importación: ' + ERROR_MESSAGE();
        
        EXEC report.Sp_LogReporte @SP = 'Pago.sp_importarPagosDesdeCSV', @Tipo = 'ERROR', @Mensaje = @MensajeError, @RutaArchivo = @rutaArchivo;
        
        PRINT @MensajeError;
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
    END CATCH;
END;
GO