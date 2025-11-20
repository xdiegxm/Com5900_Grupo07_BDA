-- Pruebas Modulares para Stored Procedures
USE master
USE Com5600G07
GO

--Cada sección se tiene que hacer completa porque el @IdConsorcio se declara al principio nomás

PRINT 'PRUEBAS'
-----------------------------
-- 1. PRUEBAS PARA CONSORCIO 
-----------------------------
PRINT 'Pruebas de Consorcio'

DECLARE @IdConsorcio INT

-- 1.1 Agregar Consorcio

EXEC @IdConsorcio = consorcio.sp_agrConsorcio
    @nombreconsorcio = 'Consorcio Prueba',
    @direccion = 'Av. Test 123',
    @superficie_total = 1200.00,
    @cant_unidades_funcionales = 8,
    @moraprimervto = 2.50,
    @moraproxvto = 5.00



-- Verificar
SELECT 'Consorcio después de agregar' as Estado, * 
FROM consorcio.Consorcio 
WHERE IdConsorcio = @IdConsorcio

-- 1.2 Modificar Consorcio

EXEC consorcio.sp_ModifConsorcio
    @IdConsorcio = @IdConsorcio,
    @NombreConsorcio = 'Consorcio Prueba Modificado',
    @MoraPrimerVTO = 3.00

-- Verificar modificación
SELECT 'Consorcio después de modificar' as Estado, * 
FROM consorcio.Consorcio 
WHERE IdConsorcio = @IdConsorcio

-- 1.3 Borrar Consorcio
PRINT '1.3 Borrando Consorcio...'
EXEC consorcio.sp_BorrarConsorcio @IdConsorcio = @IdConsorcio

-- Verificar borrado
SELECT 'Verificación borrado' as Estado, 
    CASE WHEN EXISTS(SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio) 
    THEN 'NO se borró' ELSE 'Borrado correctamente' END as Resultado

PRINT 'Pruebas de Consorcio completas'
GO

-----------------------------
-- 2. PRUEBAS PARA UF
-----------------------------
PRINT 'Pruebas de Unidad Funcional '

DECLARE @IdConsorcioUF INT
EXEC @IdConsorcioUF = consorcio.sp_agrConsorcio
    @nombreconsorcio = 'Consorcio UF Prueba',
    @direccion = 'Av. UF Test 456',
    @superficie_total = 1000.00,
    @cant_unidades_funcionales = 5,
    @moraprimervto = 2.00,
    @moraproxvto = 4.00

PRINT 'Consorcio creado: ' + CAST(@IdConsorcioUF AS VARCHAR)

-- 2.1 Agregar Unidad Funcional
PRINT '2.1 Agregando Unidad Funcional...'
DECLARE @IdUF INT
EXEC @IdUF = consorcio.so_agrUnidadFuncional
    @Piso = '3',
    @Depto = 'B',
    @Superficie = 75.00,
    @Coeficiente = 25.00,
    @IdConsorcio = @IdConsorcioUF

IF @IdUF = -1 OR @IdUF IS NULL
BEGIN
    PRINT 'ERROR: No se pudo crear la Unidad Funcional'
    RETURN
END

PRINT 'Unidad Funcional agregada con ID: ' + CAST(@IdUF AS VARCHAR)

-- Verificar
SELECT 'UF después de agregar' as Estado, * 
FROM consorcio.UnidadFuncional 
WHERE IdUF = @IdUF

-- 2.2 Modificar Unidad Funcional
PRINT '2.2 Modificando Unidad Funcional'
EXEC consorcio.sp_ModifUnidadFuncional
    @IdUF = @IdUF,
    @Piso = '4',
    @Superficie = 80.00

-- Verificar modificación
SELECT 'UF después de modificar' as Estado, * 
FROM consorcio.UnidadFuncional 
WHERE IdUF = @IdUF

-- 2.3 Borrar Unidad Funcional
PRINT '2.3 Borrando Unidad Funcional'
EXEC consorcio.sp_BorrarUnidadFuncional @IdUF = @IdUF

-- Verificar borrado
SELECT 'Verificación borrado UF' as Estado, 
    CASE WHEN EXISTS(SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF) 
    THEN 'NO se borró' ELSE 'Borrado correctamente' END as Resultado

-- Limpiar consorcio
EXEC consorcio.sp_BorrarConsorcio @IdConsorcio = @IdConsorcioUF

PRINT 'Pruebas UF completas'
GO
-----------------------------
-- 3. PRUEBAS PARA PERSONA 
-----------------------------
PRINT 'Pruebas para Persona'


DECLARE @IdConsorcioP INT
EXEC @IdConsorcioP = consorcio.sp_agrConsorcio
    @nombreconsorcio = 'Consorcio Persona Prueba',
    @direccion = 'Av. Persona Test 789',
    @superficie_total = 800.00,
    @cant_unidades_funcionales = 3,
    @moraprimervto = 1.50,
    @moraproxvto = 3.00

PRINT 'Consorcio creado: ' + CAST(@IdConsorcioP AS VARCHAR)


DECLARE @IdUFP INT
EXEC @IdUFP = consorcio.so_agrUnidadFuncional
    @Piso = '1', 
    @Depto = 'C', 
    @Superficie = 60.00, 
    @Coeficiente = 20.00, 
    @IdConsorcio = @IdConsorcioP

-- Verificar que se creó la UF
IF @IdUFP IS NULL OR @IdUFP = -1
BEGIN
    PRINT 'ERROR: No se pudo crear la Unidad Funcional'
    RETURN
END

PRINT 'Unidad Funcional creada: ' + CAST(@IdUFP AS VARCHAR)

-- 3.1 Agregar Persona

EXEC consorcio.sp_agrPersona
    @DNI = '87654321',
    @Nombre = 'María',
    @Apellido = 'Lopez',
    @Email = 'maria.lopez@test.com',
    @Telefono = '1155667788',
    @CVU = '9876543210987654321098',
    @idUF = @IdUFP

-- Verificar

SELECT 'Persona después de agregar' as Estado, * 
FROM consorcio.Persona 
WHERE DNI = '87654321'

-- 3.2 Modificar Persona
PRINT 'Modificando Persona...'
EXEC consorcio.sp_ModifPersona
    @DNI = '87654321',
    @Nombre = 'María Elena',
    @Email = 'mariaelena.lopez@test.com'

-- Verificar modificación

SELECT 'Persona después de modificar' as Estado, * 
FROM consorcio.Persona 
WHERE DNI = '87654321'

-- 3.3 Borrar Persona

EXEC consorcio.sp_BorrarPersona @DNI = '87654321'

-- Verificar borrado

SELECT 'Verificación borrado Persona' as Estado, 
    CASE WHEN EXISTS(SELECT 1 FROM consorcio.Persona WHERE DNI = '87654321') 
    THEN 'NO se borró' ELSE 'Borrado correctamente' END as Resultado

-- Limpiar

EXEC consorcio.sp_BorrarUnidadFuncional @IdUF = @IdUFP
EXEC consorcio.sp_BorrarConsorcio @IdConsorcio = @IdConsorcioP

PRINT 'Pruebas personas completado'
GO

-----------------------------
-- 4. PRUEBAS PARA EXPENSAS
-----------------------------

PRINT 'Pruebas expensas'

-- Necesitamos consorcio
DECLARE @IdConsorcioExp INT
EXEC @IdConsorcioExp = consorcio.sp_agrConsorcio
    @nombreconsorcio = 'Consorcio Expensa Prueba',
    @direccion = 'Av. Expensa Test 321',
    @superficie_total = 900.00,
    @cant_unidades_funcionales = 4,
    @moraprimervto = 2.00,
    @moraproxvto = 4.00

DECLARE @NroExpensa INT

-- 4.1 Agregar Expensa

EXEC @NroExpensa = expensas.sp_agrExpensa
    @idConsorcio = @IdConsorcioExp,
    @fechaGeneracion = '2024-02-01',
    @fechaVto1 = '2024-02-15',
    @fechaVto2 = '2024-02-28',
    @montoTotal = 4000.00
    SELECT 'Expensa agregada'
    FROM expensas.Expensa 
    WHERE nroExpensa = @NroExpensa

-- 4.2 Modificar Expensa
EXEC expensas.sp_ModifExpensa
    @NroExpensa = @NroExpensa,
    @MontoTotal = 4500.00,
    @FechaVto1 = '2024-02-20'

-- Verificar modificación
SELECT 'Expensa después de modificar' as Estado, * 
FROM expensas.Expensa 
WHERE nroExpensa = @NroExpensa

-- 4.3 Borrar Expensa
EXEC expensas.sp_BorrarExpensa @NroExpensa = @NroExpensa

-- Verificar borrado
SELECT 'Verificación borrado Expensa' as Estado, 
    CASE WHEN EXISTS(SELECT 1 FROM expensas.Expensa WHERE nroExpensa = @NroExpensa) 
    THEN 'NO se borró' ELSE 'Borrado correctamente' END as Resultado

-- Limpiar
EXEC consorcio.sp_BorrarConsorcio @IdConsorcio = @IdConsorcioExp

PRINT 'Prueba expensas completada'
GO

-----------------------------
-- 5. PRUEBAS PARA GASTOS 
-----------------------------
PRINT 'Prueba gastos completos (ordinarios + extraordinarios)'

-- Necesitamos consorcio y expensa
DECLARE @IdConsorcioGast INT
EXEC @IdConsorcioGast = consorcio.sp_agrConsorcio
    @nombreconsorcio = 'Consorcio Gasto Prueba',
    @direccion = 'Av. Gasto Test 654',
    @superficie_total = 700.00,
    @cant_unidades_funcionales = 2,
    @moraprimervto = 1.00,
    @moraproxvto = 2.00

DECLARE @NroExpensaGast INT
EXEC @NroExpensaGast = expensas.sp_agrExpensa
    @idConsorcio = @IdConsorcioGast,
    @fechaGeneracion = '2024-03-01',
    @fechaVto1 = '2024-03-15',
    @montoTotal = 2000.00

DECLARE @IdGastoOrdinario INT, @IdGastoExtraordinario INT

-- =============================================
-- 1. PRUEBAS GASTO ORDINARIO
-- =============================================
PRINT '1. PRUEBAS GASTO ORDINARIO'

-- 1.1 Agregar Gasto Ordinario
PRINT '1.1 Agregando Gasto Ordinario...'
EXEC @IdGastoOrdinario = gastos.sp_agrGasto
    @nroExpensa = @NroExpensaGast,
    @idConsorcio = @IdConsorcioGast,
    @tipo = 'Ordinario',
    @descripcion = 'Limpieza mensual prueba',
    @importe = 200.00

EXEC gastos.sp_agrGastoOrdinario
    @idGasto = @IdGastoOrdinario,
    @nombreProveedor = 'Limpieza Test SA',
    @categoria = 'Mantenimiento',
    @nroFactura = 'FAC-ORD-001-2024'

-- 1.2 Modificar Gasto Ordinario Principal
PRINT '1.2 Modificando Gasto Ordinario Principal...'
EXEC gastos.sp_ModifGasto
    @IdGasto = @IdGastoOrdinario,
    @descripcion = 'Limpieza y mantenimiento mensual',
    @importe = 250.00

-- 1.3 Modificar Detalles Gasto Ordinario
PRINT '1.3 Modificando Detalles Gasto Ordinario...'
EXEC gastos.sp_modifgastoordinario
    @idGasto = @IdGastoOrdinario,
    @nombreProveedor = 'Limpieza y Mantenimiento SA',
    @categoria = 'Limpieza',
    @nrofactura = 'FAC-ORD-002-2024'

-- =============================================
-- 2. PRUEBAS GASTO EXTRAORDINARIO
-- =============================================
PRINT '2. PRUEBAS GASTO EXTRAORDINARIO'

-- 2.1 Agregar Gasto Extraordinario
PRINT '2.1 Agregando Gasto Extraordinario...'
EXEC @IdGastoExtraordinario = gastos.sp_agrGasto
    @nroExpensa = @NroExpensaGast,
    @idConsorcio = @IdConsorcioGast,
    @tipo = 'Extraordinario',
    @descripcion = 'Reparación ascensor',
    @importe = 5000.00

EXEC gastos.sp_agrGastoExtraordinario
    @idGasto = @IdGastoExtraordinario,
    @cuotaActual = 1,
    @cantCuotas = 10

-- 2.2 Modificar Gasto Extraordinario Principal
PRINT '2.2 Modificando Gasto Extraordinario Principal...'
EXEC gastos.sp_ModifGasto
    @IdGasto = @IdGastoExtraordinario,
    @descripcion = 'Reparación completa ascensor',
    @importe = 5500.00

-- 2.3 Modificar Detalles Gasto Extraordinario - CORREGIDO
PRINT '2.3 Modificando Detalles Gasto Extraordinario...'
EXEC gastos.sp_ModifGastoExtraordinario
    @idGasto = @IdGastoExtraordinario,  
    @cuotaactual = 2,
    @cantcuotas = 12

-- =============================================
-- 3. BORRADO DE AMBOS GASTOS
-- =============================================
PRINT '3. BORRADO DE GASTOS'

EXEC gastos.sp_BorrarGastoCompleto @IdGasto = @IdGastoOrdinario
EXEC gastos.sp_BorrarGastoCompleto @IdGasto = @IdGastoExtraordinario

-- =============================================
-- 4. LIMPIEZA
-- =============================================
PRINT '4. LIMPIEZA FINAL'
EXEC expensas.sp_BorrarExpensa @NroExpensa = @NroExpensaGast
EXEC consorcio.sp_BorrarConsorcio @IdConsorcio = @IdConsorcioGast

PRINT 'Prueba gastos completos finalizada'
GO