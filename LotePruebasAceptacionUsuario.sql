USE Com5600G07
GO
SET NOCOUNT ON;

PRINT '=== INICIANDO EJECUCIÓN (VERSIÓN PIVOT) ===';

------------------------------------------------------------------------------
-- 0. LIMPIEZA
------------------------------------------------------------------------------
DELETE FROM Pago.Pago;
DELETE FROM expensas.Prorrateo;
DELETE FROM gastos.Gasto_Extraordinario;
DELETE FROM gastos.Gasto_Ordinario;
DELETE FROM gastos.Gasto;
DELETE FROM expensas.Expensa;
DELETE FROM consorcio.Ocupacion;
DELETE FROM consorcio.Persona;
DELETE FROM consorcio.Cochera;
DELETE FROM consorcio.Baulera;
DELETE FROM consorcio.UnidadFuncional;
DELETE FROM consorcio.Consorcio;

-- Reseteo de IDs
DBCC CHECKIDENT ('consorcio.Consorcio', RESEED, 0);
DBCC CHECKIDENT ('consorcio.UnidadFuncional', RESEED, 0);
DBCC CHECKIDENT ('expensas.Expensa', RESEED, 0);
DBCC CHECKIDENT ('gastos.Gasto', RESEED, 0);
DBCC CHECKIDENT ('Pago.Pago', RESEED, 0); 
GO

------------------------------------------------------------------------------
-- 1. CARGA DE CONSORCIOS
------------------------------------------------------------------------------
DECLARE @IdConsFull INT, @IdConsNada INT, @IdConsBaulera INT, @IdConsCochera INT;

INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_FULL', 'Av. Libertador 1000', 2000, 2.0, 5.0, 10);
SELECT @IdConsFull = SCOPE_IDENTITY();

INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_SIMPLE', 'Calle SinNada 123', 1000, 2.0, 5.0, 10);
SELECT @IdConsNada = SCOPE_IDENTITY();

INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_BAULERA', 'Av ConBaulera 456', 1500, 2.0, 5.0, 10);
SELECT @IdConsBaulera = SCOPE_IDENTITY();

INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_COCHERA', 'Calle ConCochera 789', 1800, 2.0, 5.0, 10);
SELECT @IdConsCochera = SCOPE_IDENTITY();

------------------------------------------------------------------------------
-- 2. CARGA DE UFs
------------------------------------------------------------------------------
PRINT '=== CARGANDO UNIDADES FUNCIONALES ===';

-- Consorcio FULL
INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'A', 50.00, 10.00, @IdConsFull), ('1', 'B', 50.00, 10.00, @IdConsFull),
('2', 'A', 50.00, 10.00, @IdConsFull), ('2', 'B', 50.00, 10.00, @IdConsFull),
('3', 'A', 50.00, 10.00, @IdConsFull), ('3', 'B', 50.00, 10.00, @IdConsFull),
('4', 'A', 50.00, 10.00, @IdConsFull), ('4', 'B', 50.00, 10.00, @IdConsFull),
('5', 'A', 50.00, 10.00, @IdConsFull), ('5', 'B', 50.00, 10.00, @IdConsFull);

INSERT INTO consorcio.Cochera (Tamanio, IdUf) SELECT 12.50, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsFull;
INSERT INTO consorcio.Baulera (Tamanio, IdUF) SELECT 2.00, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsFull;

-- Heterogeneidad (Borrar algunas cocheras/bauleras)
DELETE FROM consorcio.Cochera WHERE IdUF IN (SELECT TOP 2 IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsFull ORDER BY IdUF ASC);
DELETE FROM consorcio.Baulera WHERE IdUF IN (SELECT TOP 2 IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsFull ORDER BY IdUF DESC);

-- Otros Consorcios
INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'A', 40.00, 10.00, @IdConsNada), ('1', 'B', 40.00, 10.00, @IdConsNada),
('2', 'A', 40.00, 10.00, @IdConsNada), ('2', 'B', 40.00, 10.00, @IdConsNada),
('3', 'A', 40.00, 10.00, @IdConsNada), ('3', 'B', 40.00, 10.00, @IdConsNada),
('4', 'A', 40.00, 10.00, @IdConsNada), ('4', 'B', 40.00, 10.00, @IdConsNada),
('5', 'A', 40.00, 10.00, @IdConsNada), ('5', 'B', 40.00, 10.00, @IdConsNada);

INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'C', 45.00, 10.00, @IdConsBaulera), ('2', 'C', 45.00, 10.00, @IdConsBaulera),
('3', 'C', 45.00, 10.00, @IdConsBaulera), ('4', 'C', 45.00, 10.00, @IdConsBaulera),
('5', 'C', 45.00, 10.00, @IdConsBaulera), ('6', 'C', 45.00, 10.00, @IdConsBaulera),
('7', 'C', 45.00, 10.00, @IdConsBaulera), ('8', 'C', 45.00, 10.00, @IdConsBaulera),
('9', 'C', 45.00, 10.00, @IdConsBaulera), ('10', 'C', 45.00, 10.00, @IdConsBaulera);
INSERT INTO consorcio.Baulera (Tamanio, IdUF) SELECT 3.00, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsBaulera;

INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'D', 60.00, 10.00, @IdConsCochera), ('2', 'D', 60.00, 10.00, @IdConsCochera),
('3', 'D', 60.00, 10.00, @IdConsCochera), ('4', 'D', 60.00, 10.00, @IdConsCochera),
('5', 'D', 60.00, 10.00, @IdConsCochera), ('6', 'D', 60.00, 10.00, @IdConsCochera),
('7', 'D', 60.00, 10.00, @IdConsCochera), ('8', 'D', 60.00, 10.00, @IdConsCochera),
('9', 'D', 60.00, 10.00, @IdConsCochera), ('10', 'D', 60.00, 10.00, @IdConsCochera);
INSERT INTO consorcio.Cochera (Tamanio, IdUF) SELECT 12.50, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsCochera;

------------------------------------------------------------------------------
-- 3. CARGA DE PERSONAS
------------------------------------------------------------------------------
PRINT '=== CARGANDO PERSONAS ===';

INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, idUF)
SELECT CAST(20000000 + IdUF AS VARCHAR(10)), 'Propietario', 'Unidad ' + CAST(IdUF AS VARCHAR), 'prop'+CAST(IdUF AS VARCHAR)+'@mail.com', '1144445555', RIGHT('0000000000000000000000' + CAST(IdUF AS VARCHAR), 22), IdUF
FROM consorcio.UnidadFuncional;
INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI) SELECT 'Propietario', IdUF, CAST(20000000 + IdUF AS VARCHAR(10)) FROM consorcio.UnidadFuncional;

INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, idUF)
SELECT CAST(30000000 + IdUF AS VARCHAR(10)), 'Inquilino', 'Alquilando ' + CAST(IdUF AS VARCHAR), 'inq'+CAST(IdUF AS VARCHAR)+'@mail.com', '1155556666', RIGHT('0000000000000000009999' + CAST(IdUF AS VARCHAR), 22), IdUF
FROM consorcio.UnidadFuncional WHERE (IdUF % 2) = 0;
INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI) SELECT 'Inquilino', IdUF, CAST(30000000 + IdUF AS VARCHAR(10)) FROM consorcio.UnidadFuncional WHERE (IdUF % 2) = 0;

------------------------------------------------------------------------------
-- 4. GENERACIÓN HISTORIA Y GASTOS
------------------------------------------------------------------------------
PRINT '=== GENERANDO GASTOS ===';

-- 3 Meses para cada consorcio
INSERT INTO expensas.Expensa (idConsorcio, fechaGeneracion, fechaVto1, fechaVto2, montoTotal)
SELECT IdConsorcio, '2025-01-01', '2025-01-10', '2025-01-20', 0 FROM consorcio.Consorcio
UNION ALL
SELECT IdConsorcio, '2025-02-01', '2025-02-10', '2025-02-20', 0 FROM consorcio.Consorcio
UNION ALL
SELECT IdConsorcio, '2025-03-01', '2025-03-10', '2025-03-20', 0 FROM consorcio.Consorcio;

-- Gasto Ordinario (Todos)
INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
SELECT nroExpensa, idConsorcio, 'Ordinario', 'Limpieza General', DATEADD(day, 5, fechaGeneracion), 100000
FROM expensas.Expensa;
INSERT INTO gastos.Gasto_Ordinario (idGasto, nombreProveedor, categoria, nroFactura) 
SELECT idGasto, 'Limpieza SRL', 'Servicios', 'A-' + CAST(idGasto AS VARCHAR) FROM gastos.Gasto WHERE tipo = 'Ordinario';

-- Gasto Extraordinario 1 (Marzo, Full y Baulera)
INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
SELECT E.nroExpensa, E.idConsorcio, 'Extraordinario', 'Reparacion Fachada', '2025-03-05', 500000
FROM expensas.Expensa E
JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
WHERE MONTH(E.fechaGeneracion) = 3 AND C.NombreConsorcio IN ('CONSORCIO_TEST_FULL', 'CONSORCIO_TEST_BAULERA');
INSERT INTO gastos.Gasto_Extraordinario (idGasto, cuotaActual, cantCuotas) 
SELECT idGasto, 1, 5 FROM gastos.Gasto WHERE tipo = 'Extraordinario';

-- Gasto Extraordinario 2 (Febrero, Simple)
INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
SELECT E.nroExpensa, E.idConsorcio, 'Extraordinario', 'Reparacion Bomba Agua', '2025-02-15', 150000
FROM expensas.Expensa E
JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
WHERE MONTH(E.fechaGeneracion) = 2 AND C.NombreConsorcio = 'CONSORCIO_TEST_SIMPLE';
INSERT INTO gastos.Gasto_Extraordinario (idGasto, cuotaActual, cantCuotas) 
SELECT idGasto, 1, 3 FROM gastos.Gasto WHERE descripcion = 'Reparacion Bomba Agua';

-- Totales
UPDATE E
SET montoTotal = (SELECT SUM(importe) FROM gastos.Gasto G WHERE G.nroExpensa = E.nroExpensa)
FROM expensas.Expensa E;

-- Generar Prorrateo Inicial
INSERT INTO expensas.Prorrateo (NroExpensa, IdUF, Porcentaje, SaldoAnterior, PagosRecibidos, InteresMora, ExpensaOrdinaria, ExpensaExtraordinaria, Total, Deuda)
SELECT 
    E.nroExpensa, UF.IdUF, UF.Coeficiente,
    0, 0, 0, 
    (SELECT ISNULL(SUM(importe),0) FROM gastos.Gasto WHERE nroExpensa = E.nroExpensa AND tipo = 'Ordinario') * (UF.Coeficiente/100),
    (SELECT ISNULL(SUM(importe),0) FROM gastos.Gasto WHERE nroExpensa = E.nroExpensa AND tipo = 'Extraordinario') * (UF.Coeficiente/100),
    E.montoTotal * (UF.Coeficiente/100),
    E.montoTotal * (UF.Coeficiente/100)
FROM expensas.Expensa E
JOIN consorcio.UnidadFuncional UF ON E.idConsorcio = UF.IdConsorcio;

------------------------------------------------------------------------------
-- 5. CARGA DE PAGOS
------------------------------------------------------------------------------
PRINT '=== CARGANDO PAGOS ===';

-- Ajuste para permitir NULLs (Pago no asociado)
ALTER TABLE Pago.Pago ALTER COLUMN IdUF INT NULL;
ALTER TABLE Pago.Pago ALTER COLUMN NroExpensa INT NULL;

-- Pagos Automáticos (70% de probabilidad de pago por unidad/expensa)
INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
SELECT 
    DATEADD(day, 10 + (ABS(CHECKSUM(NEWID())) % 10), E.fechaGeneracion), 
    (E.montoTotal * (UF.Coeficiente / 100)),
    'CBU-GENERICO-AUTO-0000',
    UF.IdUF,
    E.nroExpensa
FROM consorcio.UnidadFuncional UF
JOIN expensas.Expensa E ON UF.IdConsorcio = E.idConsorcio
WHERE (ABS(CHECKSUM(NEWID())) % 10) < 7;

-- Pago No Asociado (Requisito)
INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
VALUES ('2025-02-15', 5500, 'CBU-DESCONOCIDO-999999', NULL, NULL);

-- Actualización de Saldos
UPDATE P
SET PagosRecibidos = (
    SELECT ISNULL(SUM(Pg.Importe), 0) 
    FROM Pago.Pago Pg 
    WHERE Pg.IdUF = P.IdUF 
    AND YEAR(Pg.Fecha) = YEAR(E.fechaGeneracion) 
    AND MONTH(Pg.Fecha) = MONTH(E.fechaGeneracion)
)
FROM expensas.Prorrateo P
JOIN expensas.Expensa E ON P.NroExpensa = E.nroExpensa;

UPDATE expensas.Prorrateo
SET Deuda = (ExpensaOrdinaria + ExpensaExtraordinaria + SaldoAnterior + InteresMora) - PagosRecibidos;

------------------------------------------------------------------------------
-- 6. REPORTES FINALES
------------------------------------------------------------------------------
PRINT ' ';
PRINT '##################################################################';
PRINT '################## GENERACIÓN DE ARCHIVOS CSV ####################';
PRINT '##################################################################';
PRINT ' ';

PRINT '--- [ARCHIVO 1] INFORMACIÓN GENERAL (Items 1-6) ---';

-- Encabezado
SELECT 
    C.NombreConsorcio,
    '1-ENCABEZADO' AS Categoria,
    'ADMINISTRACION GRUPO 07' AS Descripcion,
    'Direccion: ' + C.Direccion AS Detalle,
    0.00 AS Importe
FROM consorcio.Consorcio C

UNION ALL

-- Formas de Pago (Ejemplo Marzo)
SELECT 
    C.NombreConsorcio,
    '2-FORMA PAGO' AS Categoria,
    'Vencimiento 1: ' + CAST(E.fechaVto1 AS VARCHAR) AS Descripcion,
    'Vencimiento 2: ' + CAST(E.fechaVto2 AS VARCHAR) AS Detalle,
    0.00
FROM expensas.Expensa E
JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
WHERE E.fechaGeneracion = '2025-03-01'

UNION ALL

-- Deudores
SELECT 
    C.NombreConsorcio,
    '3-DEUDORES' AS Categoria,
    'UF ' + UF.Piso + '-' + UF.Depto AS Descripcion,
    P.Apellido + ' ' + P.Nombre AS Detalle,
    PR.Deuda
FROM expensas.Prorrateo PR
JOIN consorcio.UnidadFuncional UF ON PR.IdUF = UF.IdUF
JOIN consorcio.Consorcio C ON UF.IdConsorcio = C.IdConsorcio
JOIN consorcio.Persona P ON UF.IdUF = P.idUF
WHERE PR.Deuda > 0

UNION ALL

-- Gastos Detallados
SELECT 
    C.NombreConsorcio,
    CASE WHEN G.tipo = 'Ordinario' THEN '4-GASTOS ORDINARIOS' ELSE '5-GASTOS EXTRA' END AS Categoria,
    G.descripcion,
    'Fecha Factura: ' + CAST(G.fechaEmision AS VARCHAR),
    G.importe
FROM gastos.Gasto G
JOIN expensas.Expensa E ON G.nroExpensa = E.nroExpensa
JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
ORDER BY NombreConsorcio, Categoria;


PRINT ' ';
PRINT '--- [ARCHIVO 2] ITEM 7: ESTADO DE CUENTAS (FORMATO PIVOT/HORIZONTAL) ---';

SELECT 
    C.NombreConsorcio,
    UPPER(LEFT(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 1)) + 
    SUBSTRING(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 2, 20) + 
    ' ' + CAST(YEAR(E.fechaGeneracion) AS VARCHAR) AS Periodo,
    
    UF.Piso + '-' + UF.Depto AS Unidad,
    
    -- Responsable
    CASE 
        WHEN PerInq.DNI IS NOT NULL THEN PerInq.Apellido + ' ' + PerInq.Nombre + ' (Inq)'
        ELSE PerProp.Apellido + ' ' + PerProp.Nombre + ' (Prop)'
    END AS Responsable,
    
    UF.Coeficiente AS [%],
    PR.SaldoAnterior AS [Saldo Ant],
    
    -- COLUMNAS PIVOTEADAS (Horizontal)
    PR.ExpensaOrdinaria AS [Exp. Ord],
    PR.ExpensaExtraordinaria AS [Exp. Extra],
    PR.InteresMora AS [Interes],
    
    (PR.SaldoAnterior + PR.ExpensaOrdinaria + PR.ExpensaExtraordinaria + PR.InteresMora) AS [Total Expensa],
    PR.PagosRecibidos AS [Pagos],
    PR.Deuda AS [Saldo Final]

FROM expensas.Prorrateo PR
JOIN expensas.Expensa E ON PR.NroExpensa = E.nroExpensa
JOIN consorcio.UnidadFuncional UF ON PR.IdUF = UF.IdUF
JOIN consorcio.Consorcio C ON UF.IdConsorcio = C.IdConsorcio
LEFT JOIN consorcio.Ocupacion OcProp ON OcProp.IdUF = UF.IdUF AND OcProp.Rol = 'Propietario'
LEFT JOIN consorcio.Persona PerProp ON PerProp.DNI = OcProp.DNI
LEFT JOIN consorcio.Ocupacion OcInq ON OcInq.IdUF = UF.IdUF AND OcInq.Rol = 'Inquilino'
LEFT JOIN consorcio.Persona PerInq ON PerInq.DNI = OcInq.DNI

ORDER BY C.NombreConsorcio, E.nroExpensa, Unidad;
GO