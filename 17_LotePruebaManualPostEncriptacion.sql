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
/* ===========================================================
   INICIO DE LA CARGA DE DATOS (CON SEGURIDAD APLICADA)
   =========================================================== */
   USE Com5600G07
------------------------------------------------------------------------------
-- 0. LIMPIEZA Y RESETEO (Para poder re-ejecutar sin duplicados)
------------------------------------------------------------------------------
PRINT '=== 0. LIMPIANDO BASE DE DATOS PARA PRUEBA LIMPIA ===';

-- Borramos datos dependientes primero
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

-- Reiniciamos los contadores de ID a 0
DBCC CHECKIDENT ('consorcio.Consorcio', RESEED, 0);
DBCC CHECKIDENT ('consorcio.UnidadFuncional', RESEED, 0);
DBCC CHECKIDENT ('expensas.Expensa', RESEED, 0);
DBCC CHECKIDENT ('gastos.Gasto', RESEED, 0);
GO

------------------------------------------------------------------------------
-- 1. CARGA DE CONSORCIOS (4 Tipos Requeridos)
------------------------------------------------------------------------------

DECLARE @IdConsFull INT, @IdConsNada INT, @IdConsBaulera INT, @IdConsCochera INT;

-- Consorcio 1: Completo (Baulera + Cochera)
INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_FULL', 'Av. Libertador 1000', 2000, 2.0, 5.0, 10);
SELECT @IdConsFull = SCOPE_IDENTITY();

-- Consorcio 2: Simple (Sin Baulera ni Cochera)
INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_SIMPLE', 'Calle SinNada 123', 1000, 2.0, 5.0, 10);
SELECT @IdConsNada = SCOPE_IDENTITY();

-- Consorcio 3: Solo Baulera
INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_BAULERA', 'Av ConBaulera 456', 1500, 2.0, 5.0, 10);
SELECT @IdConsBaulera = SCOPE_IDENTITY();

-- Consorcio 4: Solo Cochera
INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO, CantidadUnidadesFunc)
VALUES ('CONSORCIO_TEST_COCHERA', 'Calle ConCochera 789', 1800, 2.0, 5.0, 10);
SELECT @IdConsCochera = SCOPE_IDENTITY();

------------------------------------------------------------------------------
-- 2. CARGA DE UNIDADES FUNCIONALES (10 por Consorcio)
------------------------------------------------------------------------------
PRINT '=== 2. CARGANDO UNIDADES FUNCIONALES Y COMPLEMENTOS ===';

-- Consorcio Completo (Baulera + Cochera)
INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'A', 50.00, 10.00, @IdConsFull), 
('1', 'B', 50.00, 10.00, @IdConsFull),
('2', 'A', 50.00, 10.00, @IdConsFull), 
('2', 'B', 50.00, 10.00, @IdConsFull),
('3', 'A', 50.00, 10.00, @IdConsFull), 
('3', 'B', 50.00, 10.00, @IdConsFull),
('4', 'A', 50.00, 10.00, @IdConsFull), 
('4', 'B', 50.00, 10.00, @IdConsFull),
('5', 'A', 50.00, 10.00, @IdConsFull), 
('5', 'B', 50.00, 10.00, @IdConsFull);

INSERT INTO consorcio.Cochera (Tamanio, IdUf)
SELECT 12.50, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsFull;
INSERT INTO consorcio.Baulera (Tamanio, IdUF)
SELECT 2.00, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsFull;

-- Consorcio SIMPLE (Solo UFs)
INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'A', 40.00, 10.00, @IdConsNada), 
('1', 'B', 40.00, 10.00, @IdConsNada),
('2', 'A', 40.00, 10.00, @IdConsNada), 
('2', 'B', 40.00, 10.00, @IdConsNada),
('3', 'A', 40.00, 10.00, @IdConsNada), 
('3', 'B', 40.00, 10.00, @IdConsNada),
('4', 'A', 40.00, 10.00, @IdConsNada), 
('4', 'B', 40.00, 10.00, @IdConsNada),
('5', 'A', 40.00, 10.00, @IdConsNada), 
('5', 'B', 40.00, 10.00, @IdConsNada);

-- Consorcio BAULERA (UFs + Bauleras)
INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'C', 45.00, 10.00, @IdConsBaulera), 
('2', 'C', 45.00, 10.00, @IdConsBaulera),
('3', 'C', 45.00, 10.00, @IdConsBaulera), 
('4', 'C', 45.00, 10.00, @IdConsBaulera),
('5', 'C', 45.00, 10.00, @IdConsBaulera), 
('6', 'C', 45.00, 10.00, @IdConsBaulera),
('7', 'C', 45.00, 10.00, @IdConsBaulera), 
('8', 'C', 45.00, 10.00, @IdConsBaulera),
('9', 'C', 45.00, 10.00, @IdConsBaulera), 
('10', 'C', 45.00, 10.00, @IdConsBaulera);

INSERT INTO consorcio.Baulera (Tamanio, IdUF)
SELECT 3.00, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsBaulera;

-- Consorcio COCHERA (UFs + Cocheras)
INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
VALUES 
('1', 'D', 60.00, 10.00, @IdConsCochera),
('2', 'D', 60.00, 10.00, @IdConsCochera),
('3', 'D', 60.00, 10.00, @IdConsCochera),
('4', 'D', 60.00, 10.00, @IdConsCochera),
('5', 'D', 60.00, 10.00, @IdConsCochera),
('6', 'D', 60.00, 10.00, @IdConsCochera),
('7', 'D', 60.00, 10.00, @IdConsCochera),
('8', 'D', 60.00, 10.00, @IdConsCochera),
('9', 'D', 60.00, 10.00, @IdConsCochera),
('10', 'D', 60.00, 10.00, @IdConsCochera);

INSERT INTO consorcio.Cochera (Tamanio, IdUF)
SELECT 12.50, IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsCochera;


------------------------------------------------------------------------------
-- 3. CARGA DE PERSONAS Y OCUPACIONES (CBU Único)
-- ** APLICANDO ENCRIPTACIÓN Y HASHING EN LA INSERCIÓN **
------------------------------------------------------------------------------
PRINT '=== 3. CARGANDO PERSONAS (ENCRIPTANDO DATOS SENSIBLES) ===';

-- Propietarios
-- Usamos una CTE para calcular los valores de texto plano antes de encriptar/hashear
WITH PersonaBaseData AS (
    SELECT
        IdUF,
        'prop' + CAST(IdUF AS VARCHAR) + '@mail.com' AS PlainEmail,
        '1144445555' AS PlainTelefono,
        RIGHT('0000000000000000000000' + CAST(IdUF AS VARCHAR), 22) AS PlainCVU,
        CAST(20000000 + IdUF AS VARCHAR(10)) AS DNI_Prop
    FROM consorcio.UnidadFuncional
)
INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, Email_Hash, CVU_Hash, idUF)
SELECT 
    PD.DNI_Prop,
    'Propietario',
    'Unidad ' + CAST(PD.IdUF AS VARCHAR),
    -- Cifrado de datos sensibles
    seguridad.EncryptData(PD.PlainEmail),
    seguridad.EncryptData(PD.PlainTelefono),
    seguridad.EncryptData(PD.PlainCVU),
    -- Hashing para búsquedas
    HASHBYTES('SHA2_256', PD.PlainEmail),
    HASHBYTES('SHA2_256', PD.PlainCVU),
    PD.IdUF
FROM PersonaBaseData PD;

INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI)
SELECT 'Propietario', IdUF, CAST(20000000 + IdUF AS VARCHAR(10))
FROM consorcio.UnidadFuncional;

-- Inquilinos
WITH InquilinoBaseData AS (
    SELECT
        IdUF,
        'inq' + CAST(IdUF AS VARCHAR) + '@mail.com' AS PlainEmail,
        '1155556666' AS PlainTelefono,
        RIGHT('0000000000000000009999' + CAST(IdUF AS VARCHAR), 22) AS PlainCVU,
        CAST(30000000 + IdUF AS VARCHAR(10)) AS DNI_Inq
    FROM consorcio.UnidadFuncional
    WHERE (IdUF % 2) = 0 -- Solo pares
)
INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, Email_Hash, CVU_Hash, idUF)
SELECT 
    IBD.DNI_Inq,
    'Inquilino',
    'Alquilando ' + CAST(IBD.IdUF AS VARCHAR),
    -- Cifrado de datos sensibles
    seguridad.EncryptData(IBD.PlainEmail),
    seguridad.EncryptData(IBD.PlainTelefono),
    seguridad.EncryptData(IBD.PlainCVU),
    -- Hashing para búsquedas
    HASHBYTES('SHA2_256', IBD.PlainEmail),
    HASHBYTES('SHA2_256', IBD.PlainCVU),
    IBD.IdUF
FROM InquilinoBaseData IBD;


INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI)
SELECT 'Inquilino', IdUF, CAST(30000000 + IdUF AS VARCHAR(10))
FROM consorcio.UnidadFuncional
WHERE (IdUF % 2) = 0;


------------------------------------------------------------------------------
-- 4. GENERACIÓN DE HISTORIA (Expensas y Gastos) - ENE, FEB, MAR
------------------------------------------------------------------------------
PRINT '=== 4. GENERANDO HISTORIA DE GASTOS (Para los 4 Consorcios) ===';

-- A. Crear las Expensas (Cabeceras) para los 3 meses en los 4 consorcios
INSERT INTO expensas.Expensa (idConsorcio, fechaGeneracion, fechaVto1, fechaVto2, montoTotal)
SELECT IdConsorcio, '2025-01-01', '2025-01-10', '2025-01-20', 0 FROM consorcio.Consorcio
UNION ALL
SELECT IdConsorcio, '2025-02-01', '2025-02-10', '2025-02-20', 0 FROM consorcio.Consorcio
UNION ALL
SELECT IdConsorcio, '2025-03-01', '2025-03-10', '2025-03-20', 0 FROM consorcio.Consorcio;

-- B. Insertar Gasto Ordinario (Limpieza) para TODAS las expensas generadas
INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
SELECT nroExpensa, idConsorcio, 'Ordinario', 'Limpieza General', DATEADD(day, 5, fechaGeneracion), 100000
FROM expensas.Expensa;

-- Detalle del Gasto Ordinario
INSERT INTO gastos.Gasto_Ordinario (idGasto, nombreProveedor, categoria, nroFactura) 
SELECT idGasto, 'Limpieza SRL', 'Servicios', 'A-' + CAST(idGasto AS VARCHAR)
FROM gastos.Gasto WHERE tipo = 'Ordinario';

-- C. Insertar Gasto Extraordinario (SOLO en Marzo y SOLO para Consorcio Full y Baulera para variar)
INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
SELECT E.nroExpensa, E.idConsorcio, 'Extraordinario', 'Reparacion Fachada', '2025-03-05', 500000
FROM expensas.Expensa E
JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
WHERE MONTH(E.fechaGeneracion) = 3 -- Solo Marzo
  AND C.NombreConsorcio IN ('CONSORCIO_TEST_FULL', 'CONSORCIO_TEST_BAULERA'); -- Solo en estos 2

-- Detalle del Gasto Extraordinario
INSERT INTO gastos.Gasto_Extraordinario (idGasto, cuotaActual, cantCuotas) 
SELECT idGasto, 1, 5
FROM gastos.Gasto WHERE tipo = 'Extraordinario';

-- D. Actualizar Totales en Expensa
UPDATE E
SET montoTotal = (SELECT SUM(importe) FROM gastos.Gasto G WHERE G.nroExpensa = E.nroExpensa)
FROM expensas.Expensa E;

-- E. Generar Prorrateos
-- Insertamos un prorrateo por cada UF para cada Expensa de su consorcio
INSERT INTO expensas.Prorrateo (NroExpensa, IdUF, Porcentaje, SaldoAnterior, PagosRecibidos, InteresMora, ExpensaOrdinaria, ExpensaExtraordinaria, Total, Deuda)
SELECT 
    E.nroExpensa,
    UF.IdUF,
    UF.Coeficiente,
    0, 0, 0, -- Saldos en 0
    -- Calculo Ordinario: (Total Gasto Ord * Coeficiente) / 100
    (SELECT ISNULL(SUM(importe),0) FROM gastos.Gasto WHERE nroExpensa = E.nroExpensa AND tipo = 'Ordinario') * (UF.Coeficiente/100),
    -- Calculo Extra: (Total Gasto Extra * Coeficiente) / 100
    (SELECT ISNULL(SUM(importe),0) FROM gastos.Gasto WHERE nroExpensa = E.nroExpensa AND tipo = 'Extraordinario') * (UF.Coeficiente/100),
    -- Total
    E.montoTotal * (UF.Coeficiente/100),
    E.montoTotal * (UF.Coeficiente/100)
FROM expensas.Expensa E
JOIN consorcio.UnidadFuncional UF ON E.idConsorcio = UF.IdConsorcio;

PRINT '>>> CARGA MANUAL COMPLETADA EXITOSAMENTE.';
GO

-------------------------------------------------------------------------
-- SECCIÓN DE REPORTE Y VALIDACIÓN DE SEGURIDAD
-------------------------------------------------------------------------
PRINT '=== REPORTE DE VALIDACIÓN DE DATOS ==='

--------------------------------------------------------
-- 1. VALIDACIÓN DE ENCRIPTACIÓN (Muestra datos encriptados y descifrados)
--------------------------------------------------------
PRINT ' '
PRINT '--- 1. VALIDACIÓN DE ENCRIPTACIÓN DE consorcio.Persona ---'

-- Seleccionamos los primeros 5 registros para demostrar
SELECT TOP 5
    DNI,
    Nombre,
    Email AS Email_ENCRIPTADO, -- Columna VARBINARY (ilegible)
    seguridad.DecryptData(Email) AS Email_DESCIFRADO,
    CVU AS CVU_ENCRIPTADO,
    seguridad.DecryptData(CVU) AS CVU_DESCIFRADO,
    Email_Hash AS Email_HASH
FROM consorcio.Persona
ORDER BY DNI;


--------------------------------------------------------
-- 2. VERIFICAR TOTALES (Deberían ser 40 UFs)
--------------------------------------------------------
PRINT ' '
PRINT '--- 2. TOTALES DE UNIDADES Y COMPLEMENTOS ---'
SELECT 
    (SELECT COUNT(*) FROM consorcio.UnidadFuncional) AS Total_UFs_Cargadas, -- Esperado: 40
    (SELECT COUNT(*) FROM consorcio.Cochera) AS Total_Cocheras,
    (SELECT COUNT(*) FROM consorcio.Baulera) AS Total_Bauleras,
    (SELECT COUNT(*) FROM consorcio.Persona) AS Total_Personas_Creadas; -- Esperado: 40 Prop + 20 Inq = 60

--------------------------------------------------------
-- 3. VERIFICAR EXPENSAS GENERADAS (Meses 1, 2 y 3)
--------------------------------------------------------
PRINT ' '
PRINT '--- 3. EXPENSAS GENERADAS (Esperado: Ene, Feb, Mar) ---'

SELECT 
    E.nroExpensa, 
    C.NombreConsorcio, 
    MONTH(E.fechaGeneracion) as Mes, 
    YEAR(E.fechaGeneracion) as Anio, 
    E.montoTotal
FROM expensas.Expensa E
JOIN consorcio.Consorcio C ON E.idConsorcio = C.IdConsorcio
ORDER BY Mes;

-------------------------------------------------------------------------
-- REPORTE 4: Estado de Cuentas y Prorrateo (Con asignación de Responsable)
-------------------------------------------------------------------------
PRINT '--- [ARCHIVO 2] ESTADO DE CUENTAS Y PRORRATEO (Ejecutar y guardar como CSV) ---';

-- PARTE A: EXPENSAS ORDINARIAS (A cargo del Inquilino, o Propietario si no hay inquilino)
SELECT 
    C.NombreConsorcio,
    -- CAMBIO 1: Formato forzado a Español (es-ES) con mayúscula inicial
    UPPER(LEFT(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 1)) + 
    SUBSTRING(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 2, 20) + 
    ' ' + CAST(YEAR(E.fechaGeneracion) AS VARCHAR) AS Periodo,
    
    E.nroExpensa,
    UF.Piso + '-' + UF.Depto AS Unidad,
    
    CASE 
        -- Las columnas Nombre y Apellido de Persona NO están encriptadas, por lo que se leen directo.
        WHEN PerInq.DNI IS NOT NULL THEN 'Inquilino: ' + PerInq.Nombre + ' ' + PerInq.Apellido
        ELSE 'Propietario: ' + PerProp.Nombre + ' ' + PerProp.Apellido
    END AS Responsable_Pago,
    
    'Expensa Ordinaria' AS Concepto,
    
    UF.Coeficiente AS Porcentaje_Prorrateo,
    PR.SaldoAnterior,
    PR.PagosRecibidos,
    PR.InteresMora,
    PR.ExpensaOrdinaria AS Importe_Concepto,
    (PR.ExpensaOrdinaria + PR.SaldoAnterior + PR.InteresMora - PR.PagosRecibidos) AS Total_A_Pagar

FROM expensas.Prorrateo PR
JOIN expensas.Expensa E ON PR.NroExpensa = E.nroExpensa
JOIN consorcio.UnidadFuncional UF ON PR.IdUF = UF.IdUF
JOIN consorcio.Consorcio C ON UF.IdConsorcio = C.IdConsorcio
LEFT JOIN consorcio.Ocupacion OcProp ON OcProp.IdUF = UF.IdUF AND OcProp.Rol = 'Propietario'
LEFT JOIN consorcio.Persona PerProp ON PerProp.DNI = OcProp.DNI
LEFT JOIN consorcio.Ocupacion OcInq ON OcInq.IdUF = UF.IdUF AND OcInq.Rol = 'Inquilino'
LEFT JOIN consorcio.Persona PerInq ON PerInq.DNI = OcInq.DNI

WHERE PR.ExpensaOrdinaria > 0

UNION ALL

-- PARTE B: EXPENSAS EXTRAORDINARIAS
SELECT 
    C.NombreConsorcio,
    -- CAMBIO 2: Misma lógica aplicada aquí abajo (IMPORTANTE)
    UPPER(LEFT(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 1)) + 
    SUBSTRING(FORMAT(E.fechaGeneracion, 'MMMM', 'es-ES'), 2, 20) + 
    ' ' + CAST(YEAR(E.fechaGeneracion) AS VARCHAR),
    
    E.nroExpensa,
    UF.Piso + '-' + UF.Depto,
    
    'Propietario: ' + PerProp.Nombre + ' ' + PerProp.Apellido,
    
    'Expensa Extraordinaria',
    
    UF.Coeficiente,
    0, 0, 0,
    PR.ExpensaExtraordinaria,
    PR.ExpensaExtraordinaria

FROM expensas.Prorrateo PR
JOIN expensas.Expensa E ON PR.NroExpensa = E.nroExpensa
JOIN consorcio.UnidadFuncional UF ON PR.IdUF = UF.IdUF
JOIN consorcio.Consorcio C ON UF.IdConsorcio = C.IdConsorcio
JOIN consorcio.Ocupacion OcProp ON OcProp.IdUF = UF.IdUF AND OcProp.Rol = 'Propietario'
JOIN consorcio.Persona PerProp ON PerProp.DNI = OcProp.DNI

WHERE PR.ExpensaExtraordinaria > 0

ORDER BY NombreConsorcio, nroExpensa, Unidad, Concepto;
GO