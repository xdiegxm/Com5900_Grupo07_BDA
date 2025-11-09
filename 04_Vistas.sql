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
--			   ESTADO FINANCIERO      	       --
--											   --
-------------------------------------------------
/*Composición de estado Financiero 
	• Saldo anterior: saldo de la cuenta bancaria 
	• Ingresos por pago de expensas en término: el total recaudado antes del 
	vencimiento. 
	• Ingresos por pago de expensas adeudadas: pagos recibidos por saldo deudor 
	• Ingresos por expensas adelantadas: pagos recibidos por el pago de expensas 
	adelantadas 
	• Egresos por gastos del mes: total de gastos generados en el mes 
	• Saldo al cierre: resta entre el total de ingresos y el total de egresos
*/
CREATE OR ALTER VIEW expensas.vw_EstadoFinanciero_Optimizada AS
WITH ExpensasBase AS (
    SELECT 
        E.nroExpensa,
        E.idConsorcio,
        E.fechaGeneracion,
        E.fechaVto1,
        E.fechaVto2,
        E.montoTotal,
        C.NombreConsorcio
    FROM expensas.Expensa E
    INNER JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
),
GastosAgrupados AS (
    SELECT 
        nroExpensa,
        SUM(importe) as totalGastos
    FROM gastos.Gasto
    GROUP BY nroExpensa
),
PagosAgrupados AS (
    SELECT
        P.NroExpensa,
        E.idConsorcio,
        SUM(CASE WHEN P.Fecha BETWEEN E.fechaGeneracion AND E.fechaVto1 THEN P.Importe ELSE 0 END) AS pagoEnTermino,
        SUM(CASE WHEN P.Fecha > E.fechaVto1 THEN P.Importe ELSE 0 END) AS pagoAdeudado,
        SUM(CASE WHEN P.Fecha < E.fechaGeneracion THEN P.Importe ELSE 0 END) AS pagoAdelantado,
        SUM(P.Importe) AS totalIngresos
    FROM Pago.Pago P
    INNER JOIN expensas.Expensa E ON E.nroExpensa = P.NroExpensa
    GROUP BY P.NroExpensa, E.idConsorcio
)
SELECT
    EB.nroExpensa,
    EB.idConsorcio,
    EB.NombreConsorcio,
    EB.fechaGeneracion,
    EB.montoTotal,
    ISNULL(GA.totalGastos, 0) AS Egresos,
    ISNULL(PA.pagoEnTermino, 0) AS pagoEnTermino,
    ISNULL(PA.pagoAdeudado, 0) AS pagoAdeudado,
    ISNULL(PA.pagoAdelantado, 0) AS pagoAdelantado,
    ISNULL(PA.totalIngresos, 0) AS totalIngresos,
    (ISNULL(PA.totalIngresos, 0) - ISNULL(GA.totalGastos, 0)) AS resultadoNeto
FROM ExpensasBase EB
LEFT JOIN GastosAgrupados GA ON EB.nroExpensa = GA.nroExpensa
LEFT JOIN PagosAgrupados PA ON EB.nroExpensa = PA.NroExpensa AND EB.idConsorcio = PA.idConsorcio;
GO

-- Consultar por consorcio específico
SELECT * FROM expensas.vw_EstadoFinanciero 
WHERE IdConsorcio = 1 



CREATE OR ALTER VIEW expensas.vw_EstadoCuentasProrrateo AS
WITH SuperficieTotal AS (
    SELECT 
        uf.idConsorcio,
        SUM(uf.Superficie) AS SuperficieTotal
    FROM consorcio.UnidadFuncional uf
    GROUP BY uf.idConsorcio
)
SELECT
    ROW_NUMBER() OVER (ORDER BY p.NroExpensa, p.IdUF) AS IdEstadoCuenta,
    p.NroExpensa,
    p.IdUF,
    uf.Piso,
    uf.Departamento,
    uf.TipoUnidad,
    uf.Superficie,
    (uf.Superficie / st.SuperficieTotal) * 100 AS Porcentaje,
    per.Nombre + ' ' + per.Apellido AS Propietario,
    per.Email,
    per.Telefono,
    p.SaldoAnterior,
    p.PagosRecibidos,
    p.Deuda,
    p.InteresMora,
    p.ExpensaOrdinaria,
    p.ExpensaExtraordinaria,
    p.Total AS TotalAPagar,
    c.NombreConsorcio,
    e.fechaGeneracion,
    e.fechaVto1,
    e.fechaVto2,
    CASE 
        WHEN GETDATE() BETWEEN DATEADD(DAY, 1, e.fechaVto1) AND e.fechaVto2 THEN p.Total * 0.02
        WHEN GETDATE() > e.fechaVto2 THEN p.Total * 0.05
        ELSE 0 
    END AS InteresMoraCalculado,
    CASE 
        WHEN GETDATE() BETWEEN DATEADD(DAY, 1, e.fechaVto1) AND e.fechaVto2 THEN p.Total * 1.02
        WHEN GETDATE() > e.fechaVto2 THEN p.Total * 1.05
        ELSE p.Total
    END AS TotalConMora
FROM expensas.Prorrateo p
INNER JOIN consorcio.UnidadFuncional uf ON p.IdUF = uf.IdUF
INNER JOIN consorcio.Persona per ON uf.IdPersona = per.IdPersona
INNER JOIN expensas.Expensa e ON p.NroExpensa = e.nroExpensa
INNER JOIN consorcio.Consorcio c ON e.idConsorcio = c.IdConsorcio
INNER JOIN SuperficieTotal st ON uf.idConsorcio = st.idConsorcio;
GO

CREATE OR ALTER VIEW gastos.vw_GastosDetallados AS
SELECT
    g.idGasto,
    g.nroExpensa,
    g.idConsorcio,
    c.NombreConsorcio,
    g.tipo,
    g.descripcion,
    g.fechaEmision,
    g.importe,
    go.nombreProveedor,
    go.categoria,
    go.nroFactura,
    ge.cuotaActual,
    ge.cantCuotas,
    e.fechaGeneracion,
    e.fechaVto1,
    e.fechaVto2,
    CASE 
        WHEN go.categoria = 'GASTOS BANCARIOS' THEN 'Mantenimiento cuenta bancaria'
        WHEN go.categoria = 'GASTOS DE LIMPIEZA' THEN 'Limpieza'
        WHEN go.categoria = 'GASTOS DE ADMINISTRACION' THEN 'Honorarios administración'
        WHEN go.categoria = 'SEGUROS' THEN 'Seguros'
        WHEN go.categoria = 'SERVICIOS PUBLICOS' THEN 'Servicios públicos'
        WHEN g.tipo = 'Extraordinario' THEN 'Gastos extraordinarios'
        ELSE 'Gastos generales'
    END AS CategoriaDetallada
FROM gastos.Gasto g
INNER JOIN consorcio.Consorcio c ON g.idConsorcio = c.IdConsorcio
INNER JOIN expensas.Expensa e ON g.nroExpensa = e.nroExpensa
LEFT JOIN gastos.Gasto_Ordinario go ON g.idGasto = go.idGasto
LEFT JOIN gastos.Gasto_Extraordinario ge ON g.idGasto = ge.idGasto;
GO


CREATE OR ALTER VIEW expensas.vw_DocumentosExpensas AS
SELECT
    e.nroExpensa,
    c.IdConsorcio,
    c.NombreConsorcio,
    c.Direccion AS DireccionConsorcio,
    e.fechaGeneracion,
    e.fechaVto1,
    e.fechaVto2,
    e.montoTotal,
    uf.IdUF,
    uf.Piso,
    uf.Departamento,
    p.Nombre + ' ' + p.Apellido AS Propietario,
    p.Email AS EmailPropietario,
    p.Telefono,
    pr.Porcentaje,
    pr.SaldoAnterior,
    pr.PagosRecibidos,
    pr.InteresMora,
    pr.ExpensaOrdinaria,
    pr.ExpensaExtraordinaria,
    pr.Total AS TotalUnidad,
    pr.Deuda,
    CASE 
        WHEN p.Email IS NOT NULL THEN 'Email: ' + p.Email
        WHEN p.Telefono IS NOT NULL THEN 'WhatsApp: ' + p.Telefono
        ELSE 'Copia impresa'
    END AS MetodoEnvio,
    CASE 
        WHEN GETDATE() > e.fechaVto2 THEN pr.Total * 1.05
        WHEN GETDATE() > e.fechaVto1 THEN pr.Total * 1.02
        ELSE pr.Total
    END AS TotalConMora
FROM expensas.Expensa e
INNER JOIN consorcio.Consorcio c ON e.idConsorcio = c.IdConsorcio
INNER JOIN expensas.Prorrateo pr ON e.nroExpensa = pr.NroExpensa
INNER JOIN consorcio.UnidadFuncional uf ON pr.IdUF = uf.IdUF
INNER JOIN consorcio.Persona p ON uf.IdPersona = p.IdPersona
WHERE e.fechaGeneracion >= DATEADD(MONTH, -1, GETDATE());
GO