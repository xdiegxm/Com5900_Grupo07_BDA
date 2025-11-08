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
        INSERT INTO expensas.Expensa2 (idConsorcio, fechaGeneracion, fechaVto1, fechaVto2, montoTotal)
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
            SELECT 1 FROM expensas.Expensa2 e 
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
        FROM expensas.Expensa2 e
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
            NULL, -- SaldoAnterior
            NULL, -- PagosRecibidos
            NULL, -- InteresMora
            vp.MontoPorUF, -- ExpensaOrdinaria 
            NULL, -- ExpensaExtraordinaria
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
        INNER JOIN expensas.Expensa2 e ON e.idConsorcio = c.IdConsorcio
            AND YEAR(e.fechaGeneracion) = @Anio 
            AND MONTH(e.fechaGeneracion) = s.mes;

        PRINT 'Expensas encontradas: ' + CAST(@@ROWCOUNT AS VARCHAR);

        PRINT 'Insertando gastos';
        
        -- Insertar gastos
        INSERT INTO gastos.Gasto2 (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
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
        
        INSERT INTO gastos.Gasto_Ordinario2 (idGasto, nombreProveedor, categoria, nroFactura)
        SELECT 
            g.idGasto,
            p.proveedor as nombreProveedor,
            p.categoria,
            'FAC-' + CAST(g.idGasto as VARCHAR(20)) as nroFactura
        FROM gastos.Gasto2 g
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
            AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Ordinario2 o WHERE o.idGasto = g.idGasto);

        PRINT 'Gastos ordinarios con proveedores: ' + CAST(@@ROWCOUNT AS VARCHAR);

        --gastos extraordinarios
        INSERT INTO gastos.Gasto_Extraordinario2 (idGasto, cuotaActual, cantCuotas)
        SELECT 
            g.idGasto,
            1 as cuotaActual,
            1 as cantCuotas
        FROM gastos.Gasto2 g
        WHERE g.tipo = 'Extraordinario'
            AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario2 e WHERE e.idGasto = g.idGasto);
        
        PRINT 'Gastos extraordinarios: ' + CAST(@@ROWCOUNT AS VARCHAR);
        
        PRINT 'Actualizando prorrateo con gastos reales...';

        -- totales de gastos por expensa
        IF OBJECT_ID('tempdb..#GastosPorExpensa') IS NOT NULL DROP TABLE #GastosPorExpensa;
        SELECT 
            nroExpensa,
            SUM(CASE WHEN tipo = 'Ordinario' THEN importe ELSE 0 END) as TotalOrdinario,
            SUM(CASE WHEN tipo = 'Extraordinario' THEN importe ELSE 0 END) as TotalExtraordinario,
            SUM(importe) as TotalGeneral
        INTO #GastosPorExpensa
        FROM gastos.Gasto2
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
    EXEC gastos.Sp_CargarGastosDesdeArchivo 
    @RutaArchivoJSON = 'C:\Archivos_para_el_TP\Servicios.Servicios.json',
    @RutaArchivoExcel = 'C:\Archivos_para_el_TP\datos varios.xlsx',
    @Anio = 2025,
    @DiaVto1 = 10,
    @DiaVto2 = 20;    

--pagos

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
        INNER JOIN expensas.Expensa2 e ON pr.NroExpensa = e.nroExpensa
        WHERE pt.FechaProcesada BETWEEN e.fechaGeneracion AND 
              COALESCE(e.fechaVto2, DATEADD(DAY, 30, e.fechaGeneracion))
        AND pt.NroExpensa IS NULL;

        PRINT 'Números de expensa asignados por fecha: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

        
        UPDATE #PagosTemp
        SET NroExpensa = (
            SELECT TOP 1 pr.NroExpensa
            FROM expensas.Prorrateo pr
            INNER JOIN expensas.Expensa2 e ON pr.NroExpensa = e.nroExpensa
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

                
                    DECLARE @DeudaActual DECIMAL(12,2);
                    DECLARE @PagosActuales DECIMAL(12,2);
                    DECLARE @TotalExpensa DECIMAL(12,2);                  
                    
                    INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
                    VALUES (@Fecha, @Importe, @CuentaOrigen, @IdUF, @NroExpensa);

                    SET @IdPagoInsertado = SCOPE_IDENTITY();

                   
                    UPDATE expensas.Prorrateo 
                    SET 
                        PagosRecibidos = @PagosActuales + @Importe,
                        Deuda = @TotalExpensa - (@PagosActuales + @Importe) 
                    WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

                    PRINT 'Pago procesado - ID: ' + CAST(@IdPagoInsertado AS VARCHAR(10)) + 
                          ' - Importe: $' + CAST(@Importe AS VARCHAR(20)) +
                          ' - Deuda anterior: $' + CAST(@DeudaActual AS VARCHAR(20)) +
                          ' - Deuda nueva: $' + CAST((@TotalExpensa - (@PagosActuales + @Importe)) AS VARCHAR(20)) +
                          ' - IdUF: ' + CAST(@IdUF AS VARCHAR(10)) +
                          ' - Expensa: ' + CAST(@NroExpensa AS VARCHAR(10));

                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 
                        ROLLBACK TRANSACTION;
                    
                    PRINT 'Error al procesar el id de pago' + CAST(@IdPago AS VARCHAR(10))
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
        PRINT 'Error durante la importación: '
        
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL 
            DROP TABLE #PagosTemp;
    END CATCH;
END;
GO

EXEC pago.sp_importarPagosDesdeCSV @rutaArchivo = 'C:\Archivos_para_el_tp\pagos_consorcios.csv'
