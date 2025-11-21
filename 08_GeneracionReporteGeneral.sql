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
-- Comerci Salcedo, Francisco Ivan             --
-------------------------------------------------
USE Com5600G07
GO

--------------------------------------------------------------------------------------------------
-- PROCEDIMIENTO ALMACENADO: report.sp_ReporteExpensaCompleta
--
-- OBJETIVO: Genera el conjunto completo de datos de una expensa específica, incluyendo:
-- 1. Datos del Consorcio (Encabezado)
-- 2. Propietarios con Deuda
-- 3. Detalle de Gastos (Ordinarios y Extraordinarios)
-- 4. Estado Financiero Consolidado
-- 5. Estado de Cuentas por Unidad Funcional (Prorrateo)
--
-- USO: Ejecutar y exportar las salidas (Result Sets) como archivos CSV.
--------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE report.sp_ReporteExpensaCompleta
    @NroExpensa INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar si la expensa existe
    IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE nroExpensa = @NroExpensa)
    BEGIN
        PRINT 'La Expensa con número ' + CAST(@NroExpensa AS VARCHAR) + ' no existe.';
        RETURN;
    END

    DECLARE @IdConsorcio INT;
    SELECT @IdConsorcio = idConsorcio FROM expensas.Expensa WHERE nroExpensa = @NroExpensa;

    PRINT 'Generando Reportes para Expensa Nro: ' + CAST(@NroExpensa AS VARCHAR) + ' del Consorcio ID: ' + CAST(@IdConsorcio AS VARCHAR);

    -----------------------------------------------------------------------------------------------
    -- RESULT SET 1: ENCABEZADO Y DATOS ADMINISTRATIVOS
    -- 1. Encabezado con los datos de la administración
    -- 2. Forma de pago y fecha de vencimiento
    -----------------------------------------------------------------------------------------------
    SELECT 
        'ENCABEZADO' AS TipoRegistro,
        'Nombre Administración' AS Dato, -- Se asume un nombre de administración fijo para el reporte
        'Administración Altos de Saint Just' AS Valor
    UNION ALL
    SELECT 
        'ENCABEZADO',
        'CUIT Administración',
        '30-71000000-8'
    UNION ALL
    SELECT
        'CONSORCIO',
        'Nombre',
        C.NombreConsorcio
    FROM consorcio.Consorcio C
    WHERE C.IdConsorcio = @IdConsorcio
    UNION ALL
    SELECT
        'CONSORCIO',
        'Dirección',
        C.Direccion
    FROM consorcio.Consorcio C
    WHERE C.IdConsorcio = @IdConsorcio
    UNION ALL
    SELECT
        'VENCIMIENTOS',
        'Periodo',
        UPPER(LEFT(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 1)) + SUBSTRING(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 2, 20) + ' ' + CAST(YEAR(E.fechaGeneracion) AS VARCHAR)
    FROM expensas.Expensa E
    WHERE E.nroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'VENCIMIENTOS',
        'Fecha Vto 1',
        CONVERT(VARCHAR(10), E.fechaVto1, 103)
    FROM expensas.Expensa E
    WHERE E.nroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'VENCIMIENTOS',
        'Fecha Vto 2',
        CONVERT(VARCHAR(10), E.fechaVto2, 103)
    FROM expensas.Expensa E
    WHERE E.nroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'FORMA DE PAGO',
        'Medio',
        'Transferencia Bancaria'
    UNION ALL
    SELECT
        'FORMA DE PAGO',
        'CVU (Consorcio)',
        '9876543210987654321098' -- CVU de ejemplo del consorcio
    ORDER BY TipoRegistro DESC;
    
    
    -----------------------------------------------------------------------------------------------
    -- RESULT SET 2: INFORMACIÓN DE PROPIETARIOS CON SALDO DEUDOR
    -- 3. Información de los propietarios con Saldo Deudor
    -----------------------------------------------------------------------------------------------
    SELECT 
        'DEUDOR' AS Tipo,
        P.DNI,
        P.Nombre + ' ' + P.Apellido AS NombreCompleto,
        UF.Piso + ' - ' + UF.Depto AS UnidadFuncional,
        CAST(PR.Deuda AS DECIMAL(12,2)) AS SaldoDeudor,
        CAST(PR.InteresMora AS DECIMAL(12,2)) AS InteresesAplicados,
        PR.NroExpensa AS ExpensaAdeudada
    FROM 
        expensas.Prorrateo PR
    INNER JOIN 
        consorcio.UnidadFuncional UF ON PR.IdUF = UF.IdUF
    INNER JOIN 
        consorcio.Ocupacion OC ON UF.IdUF = OC.IdUF AND OC.Rol = 'Propietario'
    INNER JOIN 
        consorcio.Persona P ON OC.DNI = P.DNI
    WHERE 
        PR.Deuda > 0
        AND UF.IdConsorcio = @IdConsorcio
    ORDER BY 
        SaldoDeudor DESC;


    -----------------------------------------------------------------------------------------------
    -- RESULT SET 3: LISTADO DE GASTOS ORDINARIOS
    -- 4. Listado de los Gastos Ordinarios
    -----------------------------------------------------------------------------------------------
    SELECT
        'ORDINARIO' AS TipoGasto,
        GO.categoria AS Categoria,
        G.descripcion AS Detalle,
        GO.nombreProveedor AS Proveedor,
        GO.nroFactura AS NroFactura,
        CONVERT(VARCHAR(10), G.fechaEmision, 103) AS FechaEmision,
        CAST(G.importe AS DECIMAL(10,2)) AS ImporteTotal
    FROM 
        gastos.Gasto G
    INNER JOIN 
        gastos.Gasto_Ordinario GO ON G.idGasto = GO.idGasto
    WHERE 
        G.nroExpensa = @NroExpensa
    ORDER BY
        G.importe DESC;


    -----------------------------------------------------------------------------------------------
    -- RESULT SET 4: LISTADO DE GASTOS EXTRAORDINARIOS
    -- 5. Listado de los Gastos Extraordinarios
    -----------------------------------------------------------------------------------------------
    SELECT
        'EXTRAORDINARIO' AS TipoGasto,
        G.descripcion AS Detalle,
        GE.cuotaActual AS CuotaActual,
        GE.cantCuotas AS CantidadCuotas,
        CONVERT(VARCHAR(10), G.fechaEmision, 103) AS FechaEmision,
        CAST(G.importe AS DECIMAL(10,2)) AS ImporteTotal
    FROM 
        gastos.Gasto G
    INNER JOIN 
        gastos.Gasto_Extraordinario GE ON G.idGasto = GE.idGasto
    WHERE 
        G.nroExpensa = @NroExpensa
    ORDER BY
        G.importe DESC;


    -----------------------------------------------------------------------------------------------
    -- RESULT SET 5: COMPOSICIÓN DEL ESTADO FINANCIERO CONSOLIDADO
    -- 6. Composicion de estado financiero
    -----------------------------------------------------------------------------------------------
    SELECT 
        'ESTADO_FINANCIERO' AS Tipo,
        'TOTAL_GASTO_ORDINARIO' AS Concepto,
        CAST(SUM(CASE WHEN G.tipo = 'Ordinario' THEN G.importe ELSE 0 END) AS DECIMAL(12,2)) AS Monto
    FROM 
        gastos.Gasto G 
    WHERE G.nroExpensa = @NroExpensa
    UNION ALL
    SELECT 
        'ESTADO_FINANCIERO',
        'TOTAL_GASTO_EXTRAORDINARIO',
        CAST(SUM(CASE WHEN G.tipo = 'Extraordinario' THEN G.importe ELSE 0 END) AS DECIMAL(12,2))
    FROM 
        gastos.Gasto G 
    WHERE G.nroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'ESTADO_FINANCIERO',
        'TOTAL_EXPENSA_A_REPARTIR',
        CAST(E.montoTotal AS DECIMAL(12,2))
    FROM 
        expensas.Expensa E 
    WHERE E.nroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'ESTADO_FINANCIERO',
        'TOTAL_PAGOS_RECIBIDOS',
        CAST(SUM(PR.PagosRecibidos) AS DECIMAL(12,2))
    FROM
        expensas.Prorrateo PR
    WHERE PR.NroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'ESTADO_FINANCIERO',
        'TOTAL_SALDO_ANTERIOR',
        CAST(SUM(PR.SaldoAnterior) AS DECIMAL(12,2))
    FROM
        expensas.Prorrateo PR
    WHERE PR.NroExpensa = @NroExpensa
    UNION ALL
    SELECT
        'ESTADO_FINANCIERO',
        'TOTAL_DEUDA_PENDIENTE',
        CAST(SUM(PR.Deuda) AS DECIMAL(12,2))
    FROM
        expensas.Prorrateo PR
    WHERE PR.NroExpensa = @NroExpensa;


    -----------------------------------------------------------------------------------------------
    -- RESULT SET 6: ESTADO DE CUENTAS Y PRORRATEO POR UNIDAD FUNCIONAL
    -- 7. Estado de cuentas y prorrateo
    -----------------------------------------------------------------------------------------------
    SELECT
        'PRORRATEO' AS Tipo,
        UF.Piso + ' - ' + UF.Depto AS UnidadFuncional,
        CAST(PR.Porcentaje AS DECIMAL(5,2)) AS CoeficienteProrrateo,
        CAST(PR.ExpensaOrdinaria AS DECIMAL(12,2)) AS ExpensaOrdinaria,
        CAST(PR.ExpensaExtraordinaria AS DECIMAL(12,2)) AS ExpensaExtraordinaria,
        CAST(PR.SaldoAnterior AS DECIMAL(12,2)) AS SaldoAnterior,
        CAST(PR.InteresMora AS DECIMAL(12,2)) AS Intereses,
        CAST(PR.Total AS DECIMAL(12,2)) AS TotalExpensaGenerada,
        CAST(PR.PagosRecibidos AS DECIMAL(12,2)) AS PagosRecibidos,
        CAST(PR.Deuda AS DECIMAL(12,2)) AS DeudaActual
    FROM
        expensas.Prorrateo PR
    INNER JOIN 
        consorcio.UnidadFuncional UF ON PR.IdUF = UF.IdUF
    WHERE
        PR.NroExpensa = @NroExpensa
    ORDER BY
        UnidadFuncional;

END
GO

EXEC report.sp_ReporteExpensaCompleta @NroExpensa = 2;
