CREATE OR ALTER PROCEDURE Pago.sp_importarPagos
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
                    PRINT 'Error al insertar pago ID ' + CAST(@IdPago AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
                END CATCH;
            END
            ELSE
            BEGIN
                PRINT 'Registro omitido - ' +
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
        PRINT '❌ Error durante la importación: ' + ERROR_MESSAGE();
        PRINT 'Detalle del error: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
    END CATCH;
END;
GO
exec pago.sp_importarPagosDesdeCSV @rutaArchivo = 'C:\Archivos_para_el_tp\pagos_consorcios.csv'


select * from Pago.Pago

select * from consorcio.Persona p
inner join pago.pago pp on p.CVU = pp.CuentaOrigen

