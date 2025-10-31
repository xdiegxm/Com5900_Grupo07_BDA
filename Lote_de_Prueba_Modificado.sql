USE master

USE Com5600G07
GO


----------------
SET NOCOUNT ON;

----------------------------------------------------------------
-- 0) Insertar/asegurar persona (propietario)
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM consorcio.Persona WHERE DNI = '12345678')
BEGIN
    INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU)
    VALUES ('12345678', 'Juan', 'Perez', 'juan.perez@correo.com', '155512345', NULL);
END

----------------------------------------------------------------
-- 1) Consorcio
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = 1)
BEGIN
    INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO)
    VALUES ('Consorcio Prueba', N'Av. Siempre Viva 123', 1200.00, 2.50, 1.50);
END

----------------------------------------------------------------
-- 2) UnidadFuncional (usa Propietario = DNI)
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = 1)
BEGIN
    INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio, Propietario)
    VALUES (N'1', N'A', 65.00, 4.50, 1, '12345678');
END

----------------------------------------------------------------
-- 3) Insertar Expensa (si falta) -- respeta expensas.Expensa original
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE Tipo = 'O' AND NroExpensa = 100)
BEGIN
    INSERT INTO expensas.Expensa
    (Tipo, NroExpensa, Mes, Anio, FechaEmision, Vencimiento, Total, EstadoEnvio, MetodoEnvio, DestinoEnvio, IdConsorcio)
    VALUES ('O', 100, 10, 2025, '2025-10-01', '2025-10-31', 50000.00, 'Pendiente', 'Email', N'Juan Perez', 1);
END

----------------------------------------------------------------
-- 4) Insertar Prorrateo
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM expensas.Prorrateo WHERE Tipo = 'O' AND NroExpensa = 100 AND IdUF = 1)
BEGIN
    INSERT INTO expensas.Prorrateo
    (Tipo, NroExpensa, IdUF, SaldoAnterior, PagosRecibidos, InteresMora, ExpensaOrdinaria, ExpensaExtraordinaria, Total, Deuda)
    VALUES ('O', 100, 1, 1000.00, 0.00, 0.00, 5000.00, 0.00, 6000.00, 6000.00);
END

----------------------------------------------------------------
-- 5) Insertar EstadoFinanciero
----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM expensas.EstadoFinanciero WHERE IdFinanzas = 1)
BEGIN
    INSERT INTO expensas.EstadoFinanciero
    (SaldoAnterior, Ingresos, Egresos, SaldoCierre, Tipo, NroExpensa)
    VALUES (10000.00, 2000.00, 1500.00, 10500.00, 'O', 100);
END

----------------------------------------------------------------
-- 6) EJECUTAR SPs para probar (modificaciones)
----------------------------------------------------------------
PRINT('--- Ejecutando sp_ModifExpensa (prueba) ---');
EXEC expensas.sp_ModifExpensa
    @Tipo = 'O',
    @NroExpensa = 100,
    @Mes = 11,
    @Anio = 2025,
    @FechaEmision = NULL,
    @Vencimiento = NULL,
    @Total = 55000.00,
    @EstadoEnvio = 'Enviado',
    @MetodoEnvio = 'WhatsApp',
    @DestinoEnvio = N'Encargado',
    @IdConsorcio = 1;

PRINT('--- Ejecutando sp_ModifProrrateo (prueba) ---');
EXEC expensas.sp_ModifProrrateo
    @Tipo = 'O',
    @NroExpensa = 100,
    @IdUF = 1,
    @SaldoAnterior = NULL,
    @PagosRecibidos = 2000.00,
    @InteresMora = 100.00,
    @ExpensaOrdinaria = NULL,
    @ExpensaExtraordinaria = 500.00,
    @Total = 5600.00,
    @Deuda = 3600.00;

PRINT('--- Ejecutando sp_ModifEstadoFinanciero (prueba) ---');
EXEC expensas.sp_ModifEstadoFinanciero
    @IdFinanzas = 1,
    @SaldoAnterior = NULL,
    @Ingresos = 3000.00,
    @Egresos = 2500.00,
    @SaldoCierre = NULL,
    @Tipo = 'O',
    @NroExpensa = 100;

----------------------------------------------------------------
-- 7) Mostrar registros resultantes
----------------------------------------------------------------
PRINT('--- Expensa ---');
SELECT * FROM expensas.Expensa WHERE Tipo = 'O' AND NroExpensa = 100;

PRINT('--- Prorrateo ---');
SELECT * FROM expensas.Prorrateo WHERE Tipo = 'O' AND NroExpensa = 100 AND IdUF = 1;

PRINT('--- EstadoFinanciero ---');
SELECT * FROM expensas.EstadoFinanciero WHERE IdFinanzas = 1;

----------------------------------------------------------------
-- 8) ROLLBACK / LIMPIEZA (opcionales)
-- Descomentar si querés dejar todo limpio después de la prueba.
----------------------------------------------------------------
/*
PRINT('--- Limpieza: eliminando datos de prueba ---');
DELETE FROM expensas.EstadoFinanciero WHERE IdFinanzas = 1;
DELETE FROM expensas.Prorrateo WHERE Tipo = 'O' AND NroExpensa = 100 AND IdUF = 1;
DELETE FROM expensas.Expensa WHERE Tipo = 'O' AND NroExpensa = 100;
DELETE FROM consorcio.UnidadFuncional WHERE IdUF = 1;
DELETE FROM consorcio.Persona WHERE DNI = '12345678';
DELETE FROM consorcio.Consorcio WHERE IdConsorcio = 1;
*/

SET NOCOUNT OFF;
