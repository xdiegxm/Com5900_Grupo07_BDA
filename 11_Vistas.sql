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
-------------------------------------------------
--											   --
--			   ESTADO FINANCIERO      	       --
--											   --
-------------------------------------------------
USE Com5600G07
GO
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
    EB.fechaVto1,
    EB.fechaVto2,
    ISNULL(GA.totalGastos, 0) AS Egresos,
    ISNULL(PA.pagoEnTermino, 0) AS pagoEnTermino,
    ISNULL(PA.pagoAdeudado, 0) AS pagoAdeudado,
    ISNULL(PA.pagoAdelantado, 0) AS pagoAdelantado,
    ISNULL(PA.totalIngresos, 0) AS totalIngresos,
    (ISNULL(PA.totalIngresos, 0) - ISNULL(GA.totalGastos, 0)) AS resultadoNeto,
    -- Cálculos adicionales útiles
    CASE 
        WHEN ISNULL(PA.totalIngresos, 0) > 0 THEN 
            (ISNULL(PA.pagoEnTermino, 0) / ISNULL(PA.totalIngresos, 0)) * 100 
        ELSE 0 
    END AS porcentajePagoEnTermino
FROM ExpensasBase EB
LEFT JOIN GastosAgrupados GA ON EB.nroExpensa = GA.nroExpensa
LEFT JOIN PagosAgrupados PA ON EB.nroExpensa = PA.NroExpensa AND EB.idConsorcio = PA.idConsorcio;
GO

-- Consultar por consorcio específico
SELECT * FROM expensas.vw_EstadoFinanciero_Optimizada
WHERE IdConsorcio = 3

