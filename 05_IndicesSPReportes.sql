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
--		   ÍNDICES PARA OPTIMIZACIÓN           --
--		          DE REPORTES                  --
--											   --
-------------------------------------------------
--NO DECLARE TODOS LOS INDICES, SOLO CARGUE A SU BASE DE DATOS LOS QUE NECESITE Y USE FRECUENTEMENTE
--TENER INDICES SIN USAR EMPEORA LA PERFORMANCE DE LA BDD
-- =============================================
-- ÍNDICES PARA TABLA Pago.Pago
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_Fecha_IdUF_NroExpensa' AND object_id = OBJECT_ID('Pago.Pago'))
    CREATE NONCLUSTERED INDEX IX_Pago_Fecha_IdUF_NroExpensa 
    ON Pago.Pago (Fecha, IdUF, NroExpensa) 
    INCLUDE (Importe);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_IdUF_Fecha' AND object_id = OBJECT_ID('Pago.Pago'))
    CREATE NONCLUSTERED INDEX IX_Pago_IdUF_Fecha 
    ON Pago.Pago (IdUF, Fecha) 
    INCLUDE (Importe, NroExpensa);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_Fecha_NroExpensa_IdUF' AND object_id = OBJECT_ID('Pago.Pago'))
    CREATE NONCLUSTERED INDEX IX_Pago_Fecha_NroExpensa_IdUF 
    ON Pago.Pago (Fecha, NroExpensa, IdUF) 
    INCLUDE (Importe);

-- =============================================
-- ÍNDICES PARA TABLA expensas.Prorrateo
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prorrateo_NroExpensa_IdUF' AND object_id = OBJECT_ID('expensas.Prorrateo'))
    CREATE NONCLUSTERED INDEX IX_Prorrateo_NroExpensa_IdUF 
    ON expensas.Prorrateo (NroExpensa, IdUF) 
    INCLUDE (ExpensaOrdinaria, ExpensaExtraordinaria, Deuda);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prorrateo_Deuda_IdUF' AND object_id = OBJECT_ID('expensas.Prorrateo'))
    CREATE NONCLUSTERED INDEX IX_Prorrateo_Deuda_IdUF 
    ON expensas.Prorrateo (Deuda DESC, IdUF) 
    INCLUDE (NroExpensa, ExpensaOrdinaria, ExpensaExtraordinaria);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Prorrateo_NroExpensa' AND object_id = OBJECT_ID('expensas.Prorrateo'))
    CREATE NONCLUSTERED INDEX IX_Prorrateo_NroExpensa 
    ON expensas.Prorrateo (NroExpensa) 
    INCLUDE (ExpensaOrdinaria, ExpensaExtraordinaria, IdUF, Deuda);

-- =============================================
-- ÍNDICES PARA TABLA consorcio.UnidadFuncional
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_IdConsorcio' AND object_id = OBJECT_ID('consorcio.UnidadFuncional'))
    CREATE NONCLUSTERED INDEX IX_UnidadFuncional_IdConsorcio 
    ON consorcio.UnidadFuncional (IdConsorcio) 
    INCLUDE (IdUF, Piso, Depto, Superficie, Coeficiente);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_IdConsorcio_IdUF' AND object_id = OBJECT_ID('consorcio.UnidadFuncional'))
    CREATE NONCLUSTERED INDEX IX_UnidadFuncional_IdConsorcio_IdUF 
    ON consorcio.UnidadFuncional (IdConsorcio, IdUF) 
    INCLUDE (Piso, Depto);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_IdConsorcio_Piso_Depto' AND object_id = OBJECT_ID('consorcio.UnidadFuncional'))
    CREATE NONCLUSTERED INDEX IX_UnidadFuncional_IdConsorcio_Piso_Depto 
    ON consorcio.UnidadFuncional (IdConsorcio) 
    INCLUDE (IdUF, Piso, Depto);

-- =============================================
-- ÍNDICES PARA TABLA expensas.Expensa
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Expensa_idConsorcio_nroExpensa' AND object_id = OBJECT_ID('expensas.Expensa'))
    CREATE NONCLUSTERED INDEX IX_Expensa_idConsorcio_nroExpensa 
    ON expensas.Expensa (idConsorcio, nroExpensa) 
    INCLUDE (fechaGeneracion, montoTotal);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Expensa_nroExpensa_IdConsorcio' AND object_id = OBJECT_ID('expensas.Expensa'))
    CREATE NONCLUSTERED INDEX IX_Expensa_nroExpensa_IdConsorcio 
    ON expensas.Expensa (nroExpensa, idConsorcio) 
    INCLUDE (fechaGeneracion, montoTotal);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Expensa_idConsorcio_fechaGeneracion' AND object_id = OBJECT_ID('expensas.Expensa'))
    CREATE NONCLUSTERED INDEX IX_Expensa_idConsorcio_fechaGeneracion 
    ON expensas.Expensa (idConsorcio, fechaGeneracion) 
    INCLUDE (nroExpensa, montoTotal);

-- =============================================
-- ÍNDICES PARA TABLA gastos.Gasto
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gasto_fechaEmision_idConsorcio' AND object_id = OBJECT_ID('gastos.Gasto'))
    CREATE NONCLUSTERED INDEX IX_Gasto_fechaEmision_idConsorcio 
    ON gastos.Gasto (fechaEmision, idConsorcio) 
    INCLUDE (importe, tipo, nroExpensa);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gasto_idConsorcio_fechaEmision' AND object_id = OBJECT_ID('gastos.Gasto'))
    CREATE NONCLUSTERED INDEX IX_Gasto_idConsorcio_fechaEmision 
    ON gastos.Gasto (idConsorcio, fechaEmision) 
    INCLUDE (importe, tipo);

-- =============================================
-- ÍNDICES PARA TABLA consorcio.Persona
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Persona_idUF' AND object_id = OBJECT_ID('consorcio.Persona'))
    CREATE NONCLUSTERED INDEX IX_Persona_idUF 
    ON consorcio.Persona (idUF) 
    INCLUDE (Nombre, Apellido, DNI, Email, Telefono);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Persona_idUF_DNI' AND object_id = OBJECT_ID('consorcio.Persona'))
    CREATE NONCLUSTERED INDEX IX_Persona_idUF_DNI 
    ON consorcio.Persona (idUF, DNI) 
    INCLUDE (Nombre, Apellido, Email, Telefono);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Persona_DNI' AND object_id = OBJECT_ID('consorcio.Persona'))
    CREATE NONCLUSTERED INDEX IX_Persona_DNI 
    ON consorcio.Persona (DNI) 
    INCLUDE (Nombre, Apellido, idUF);

-- =============================================
-- ÍNDICES PARA TABLA consorcio.Consorcio
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Consorcio_IdConsorcio_Nombre' AND object_id = OBJECT_ID('consorcio.Consorcio'))
    CREATE NONCLUSTERED INDEX IX_Consorcio_IdConsorcio_Nombre 
    ON consorcio.Consorcio (IdConsorcio) 
    INCLUDE (NombreConsorcio, Direccion);

-- =============================================
-- ÍNDICES PARA TABLAS SECUNDARIAS
-- =============================================

-- Índices para gastos.Gasto_Ordinario
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gasto_Ordinario_idGasto' AND object_id = OBJECT_ID('gastos.Gasto_Ordinario'))
    CREATE NONCLUSTERED INDEX IX_Gasto_Ordinario_idGasto 
    ON gastos.Gasto_Ordinario (idGasto) 
    INCLUDE (nombreProveedor, categoria);

-- Índices para gastos.Gasto_Extraordinario
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gasto_Extraordinario_idGasto' AND object_id = OBJECT_ID('gastos.Gasto_Extraordinario'))
    CREATE NONCLUSTERED INDEX IX_Gasto_Extraordinario_idGasto 
    ON gastos.Gasto_Extraordinario (idGasto) 
    INCLUDE (cuotaActual, cantCuotas);

-- Índices para consorcio.Ocupacion
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ocupacion_IdUF' AND object_id = OBJECT_ID('consorcio.Ocupacion'))
    CREATE NONCLUSTERED INDEX IX_Ocupacion_IdUF 
    ON consorcio.Ocupacion (IdUF) 
    INCLUDE (DNI, Rol);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ocupacion_DNI' AND object_id = OBJECT_ID('consorcio.Ocupacion'))
    CREATE NONCLUSTERED INDEX IX_Ocupacion_DNI 
    ON consorcio.Ocupacion (DNI) 
    INCLUDE (IdUF, Rol);

-- =============================================
-- ÍNDICES ESPECIALES PARA FUNCIONES DE VENTANA
-- =============================================
-- Índice optimizado para LAG() en sp_ReporteDiasEntrePagos
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pago_IdUF_Fecha_Completo' AND object_id = OBJECT_ID('Pago.Pago'))
    CREATE NONCLUSTERED INDEX IX_Pago_IdUF_Fecha_Completo 
    ON Pago.Pago (IdUF, Fecha) 
    INCLUDE (Importe, NroExpensa, CuentaOrigen);

-- =============================================
-- VERIFICACIÓN Y RESUMEN
-- =============================================
-- Mostrar resumen de índices creados
SELECT 
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS IndexedColumns,
    STRING_AGG(ic2.name, ', ') AS IncludedColumns
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
LEFT JOIN (
    SELECT ic.object_id, ic.index_id, c.name
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE ic.is_included_column = 1
) ic2 ON i.object_id = ic2.object_id AND i.index_id = ic2.index_id
WHERE i.name LIKE 'IX_%'
    AND i.is_primary_key = 0
    AND i.is_unique_constraint = 0
GROUP BY t.schema_id, t.name, i.name, i.type_desc
ORDER BY SchemaName, TableName, IndexName;

PRINT 'Script de índices completado.';