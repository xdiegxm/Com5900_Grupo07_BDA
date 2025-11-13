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
--			    DROPS Y TRUNCATE		       --
--											   --
-------------------------------------------------

-------------------------------------------------
--        ELIMINACIÓN DE LAS TABLAS            --
-------------------------------------------------
-- Drop tables en orden correcto respetando dependencias
DROP TABLE IF EXISTS expensas.HistoricoProrrateo;
DROP TABLE IF EXISTS gastos.Gasto_Extraordinario;
DROP TABLE IF EXISTS gastos.Gasto_Ordinario;
DROP TABLE IF EXISTS gastos.Gasto;
DROP TABLE IF EXISTS expensas.Prorrateo;
DROP TABLE IF EXISTS Pago.Pago;
DROP TABLE IF EXISTS expensas.EstadoFinanciero;
DROP TABLE IF EXISTS expensas.Expensa;
DROP TABLE IF EXISTS consorcio.Ocupacion;
DROP TABLE IF EXISTS consorcio.Baulera;
DROP TABLE IF EXISTS consorcio.Cochera;
DROP TABLE IF EXISTS consorcio.Persona;
DROP TABLE IF EXISTS consorcio.UnidadFuncional;
DROP TABLE IF EXISTS consorcio.Consorcio;
DROP TABLE IF EXISTS report.logsReportes;
-------------------------------------------------
--											   --
--			    TRUNCATE TABLES                --
--											   --
-------------------------------------------------
-- Desactivar restricciones de clave foránea temporalmente
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';

-- Truncar tablas en orden inverso a las dependencias (de más dependiente a menos dependiente)
TRUNCATE TABLE expensas.HistoricoProrrateo;
TRUNCATE TABLE gastos.Gasto_Extraordinario;
TRUNCATE TABLE gastos.Gasto_Ordinario;
TRUNCATE TABLE gastos.Gasto;
TRUNCATE TABLE expensas.Prorrateo;
TRUNCATE TABLE Pago.Pago;
TRUNCATE TABLE expensas.EstadoFinanciero;
TRUNCATE TABLE expensas.Expensa;
TRUNCATE TABLE consorcio.Ocupacion;
TRUNCATE TABLE consorcio.Baulera;
TRUNCATE TABLE consorcio.Cochera;
TRUNCATE TABLE consorcio.Persona;
TRUNCATE TABLE consorcio.UnidadFuncional;
TRUNCATE TABLE consorcio.Consorcio;
TRUNCATE TABLE report.logsReportes;

-- Reactivar restricciones de clave foránea

EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL';