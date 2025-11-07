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
        
        -- Tabla temporal para staging del JSON
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

        PRINT 'Insertando gastos';
        
        -- Insertar gastos principales
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

        -- Insertar en gastos extraordinarios
        INSERT INTO gastos.Gasto_Extraordinario2 (idGasto, cuotaActual, cantCuotas)
        SELECT 
            g.idGasto,
            1 as cuotaActual,
            1 as cantCuotas
        FROM gastos.Gasto2 g
        WHERE g.tipo = 'Extraordinario'
            AND NOT EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario2 e WHERE e.idGasto = g.idGasto);
        
        PRINT 'Gastos extraordinarios: ' + CAST(@@ROWCOUNT AS VARCHAR);
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ';
        THROW;
    END CATCH
END
GO
---------------------------------------------------------------------
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

--Primero crear las tablas nuevas 
--Después los procedures

EXEC gastos.Sp_CargarGastosDesdeArchivo 
    @RutaArchivoJSON = 'C:\Archivos_para_el_TP\Servicios.Servicios.json',
    @RutaArchivoExcel = 'C:\Archivos_para_el_TP\datos varios.xlsx',
    @Anio = 2025,
    @DiaVto1 = 10,
    @DiaVto2 = 20;







-- Verificar resultados
select * from expensas.Expensa2
select * from gastos.Gasto2
select * from gastos.Gasto_Ordinario2
select * from gastos.Gasto_Extraordinario2

--Borrar tablas
TRUNCATE TABLE gastos.Gasto_Extraordinario2;
TRUNCATE TABLE gastos.Gasto_Ordinario2;
delete from  gastos.Gasto2;
delete from expensas.Expensa2;



