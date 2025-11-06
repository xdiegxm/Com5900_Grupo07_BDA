use com5600g07
go

CREATE TABLE expensas.Expensa2 (
    nroExpensa INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    idConsorcio INT NOT NULL,
    fechaGeneracion DATE NOT NULL,
    fechaVto1 DATE,
    fechaVto2 DATE,
    montoTotal DECIMAL(10,2),
    CONSTRAINT FK_Expensa_Consorcio FOREIGN KEY (idConsorcio) REFERENCES consorcio.Consorcio (IdConsorcio)
);
go

CREATE TABLE gastos.Gasto2 (
    idGasto INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    nroExpensa INT NOT NULL,
    idConsorcio INT NOT NULL,
    tipo VARCHAR(16) CHECK (tipo IN ('Ordinario','Extraordinario')),
    descripcion VARCHAR(200),
    fechaEmision DATE DEFAULT GETDATE(),
    importe DECIMAL(10,2) DEFAULT 0,
    CONSTRAINT FK_Gasto_Consorcio
        FOREIGN KEY (idConsorcio) REFERENCES consorcio.Consorcio (IdConsorcio),
    CONSTRAINT FK_Gasto_Expensa
        FOREIGN KEY (nroExpensa) REFERENCES expensas.Expensa2 (nroExpensa)
);
go

CREATE TABLE gastos.Gasto_Ordinario2 (
    idGasto INT NOT NULL PRIMARY KEY,
    nombreProveedor VARCHAR(100),
    categoria VARCHAR(35),
    nroFactura VARCHAR(50),
    CONSTRAINT FK_Ordinario_Gasto
        FOREIGN KEY (idGasto) REFERENCES gastos.Gasto2 (idGasto)
);
go

CREATE TABLE gastos.Gasto_Extraordinario2 (
    idGasto INT NOT NULL PRIMARY KEY,
    cuotaActual TINYINT,
    cantCuotas TINYINT,
    CONSTRAINT FK_Extraordinario_Gasto2
        FOREIGN KEY (idGasto) REFERENCES gastos.Gasto2 (idGasto)
);
go

----------------------------------------------------

CREATE OR ALTER PROCEDURE importacion.Sp_CargarGastosDesdeJson
    @JsonContent NVARCHAR(MAX),
    @Anio INT,
    @DiaVto1 INT, 
    @DiaVto2 INT
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '=== INICIANDO CARGA DESDE JSON ===';
    
    BEGIN TRY
        -- Tabla temporal para staging
        IF OBJECT_ID('tempdb..#stg_gasto') IS NOT NULL DROP TABLE #stg_gasto;
        CREATE TABLE #stg_gasto (
            consorcio NVARCHAR(200),
            mes_raw NVARCHAR(50),
            mes TINYINT,
            categoria NVARCHAR(100),
            importe_raw NVARCHAR(100),
            importe DECIMAL(18,2)
        );

        -- Insertar datos del JSON
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

        -- Actualizar con conversiones
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

        PRINT 'Registros en staging: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- Verificar que existen TODOS los consorcios del JSON
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

        -- Tabla temporal para consorcios
        IF OBJECT_ID('tempdb..#cons') IS NOT NULL DROP TABLE #cons;
        SELECT DISTINCT c.IdConsorcio, s.consorcio
        INTO #cons
        FROM #stg_gasto s
        INNER JOIN consorcio.Consorcio c ON c.NombreConsorcio = s.consorcio;

        PRINT 'Consorcios a procesar: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- Calcular totales por consorcio y mes
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

        -- Tabla temporal para expensas
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

        -- Insertar en gastos ordinarios
        INSERT INTO gastos.Gasto_Ordinario2 (idGasto, nombreProveedor, categoria, nroFactura)
        SELECT 
            g.idGasto,
            CASE 
                WHEN g.descripcion LIKE '%AGUA%' THEN 'AYSA'
                WHEN g.descripcion LIKE '%LUZ%' THEN 'EDENOR'
                WHEN g.descripcion LIKE '%BANCARIOS%' THEN 'BANCO'
                WHEN g.descripcion LIKE '%LIMPIEZA%' THEN 'EMPRESA LIMPIEZA'
                WHEN g.descripcion LIKE '%ADMINISTRACION%' THEN 'ADMINISTRADOR'
                WHEN g.descripcion LIKE '%SEGUROS%' THEN 'ASEGURADORA'
                ELSE 'PROVEEDOR'
            END as nombreProveedor,
            LEFT(g.descripcion, 35) as categoria,
            'FAC-' + CAST(g.idGasto as VARCHAR(20)) as nroFactura
        FROM gastos.Gasto2 g
        WHERE g.tipo = 'Ordinario'
          AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Ordinario2 o WHERE o.idGasto = g.idGasto);

        PRINT 'Cant gastos ordinarios insertados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        -- Insertar en gastos extraordinarios
        INSERT INTO gastos.Gasto_Extraordinario2 (idGasto, cuotaActual, cantCuotas)
        SELECT 
            g.idGasto,
            1 as cuotaActual,
            1 as cantCuotas
        FROM gastos.Gasto2 g
        WHERE g.tipo = 'Extraordinario'
          AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario2 e WHERE e.idGasto = g.idGasto);
        PRINT 'Cant gastos extraordinarios insertados: ' + CAST(@@ROWCOUNT AS VARCHAR);
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
        PRINT 'Línea: ' + CAST(ERROR_LINE() AS VARCHAR);
        THROW;
    END CATCH
END
go

CREATE OR ALTER PROCEDURE gastos.Sp_CargarGastosDesdeArchivo
    @RutaArchivo NVARCHAR(500),
    @Anio INT = 2024,
    @DiaVto1 INT = 10,
    @DiaVto2 INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Leyendo archivo: ' + @RutaArchivo;
    
    DECLARE @JsonContent NVARCHAR(MAX);
    DECLARE @Sql NVARCHAR(MAX);
    
    -- Leer el archivo JSON
    SET @Sql = N'
    SELECT @JsonContent = BulkColumn
    FROM OPENROWSET(BULK ''' + @RutaArchivo + ''', SINGLE_CLOB) AS j;';
    
    EXEC sp_executesql @Sql, N'@JsonContent NVARCHAR(MAX) OUTPUT', @JsonContent OUTPUT;
    
    IF @JsonContent IS NULL
    BEGIN
        RAISERROR('No se pudo leer el archivo JSON', 16, 1);
        RETURN;
    END
    
    -- Llamar al procedimiento original con el contenido
    EXEC importacion.Sp_CargarGastosDesdeJson 
        @JsonContent = @JsonContent,
        @Anio = @Anio,
        @DiaVto1 = @DiaVto1,
        @DiaVto2 = @DiaVto2;
END
go

EXEC importacion.Sp_CargarGastosDesdeArchivo 
    @RutaArchivo = 'C:\Archivos_para_el_TP\Servicios.Servicios.json',
    @Anio = 2024,
    @DiaVto1 = 10,
    @DiaVto2 = 20;

select * from expensas.Expensa2
select * from gastos.Gasto2
select * from gastos.Gasto_Ordinario2
select * from gastos.Gasto_Extraordinario2