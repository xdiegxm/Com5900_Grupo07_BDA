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
USE Com5600G07
GO
-------------------------------------------------
--			 								   --
--		       	  CREAR ROLES          	       --
--											   --
-------------------------------------------------

CREATE ROLE administrativo_general;
CREATE ROLE administrativo_bancario;
CREATE ROLE administrativo_operativo;
CREATE ROLE sistemas;
GO


-------------------------------------------------
--			 								   --
--		     ADMINISTRATIVO GENERAL            --
--											   --
-------------------------------------------------
-- Acutualizacion de datos de UF: SI
-- Importacion de informacion Bancaria: NO
-- Generacion de reportes : SI
------------------------------------------------
-------------------------------------------------
--             Actualizacion datos UF          --
-------------------------------------------------

GRANT EXECUTE ON ImportarConsorciosDesdeExcel TO administrativo_general;
GRANT EXECUTE ON consorcio.importarunidadesfuncionales TO administrativo_general;
GRANT EXECUTE ON consorcio.importarPersonas TO administrativo_general;
GRANT EXECUTE ON consorcio.importarocupaciones TO administrativo_general;
GRANT EXECUTE ON gastos.Sp_CargarGastosDesdeArchivo TO administrativo_general;

-------------------------------------------------
--     Importacion de informacion bancaria     --
-------------------------------------------------

DENY EXECUTE ON Pago.sp_importarPagosDesdeCSV  TO administrativo_general;

-------------------------------------------------
--          Generacion de Reportes             --
-------------------------------------------------

GRANT EXECUTE ON SCHEMA::report TO administrativo_general;


-------------------------------------------------
--             Permisos generales              --
-------------------------------------------------


DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::report TO administrativo_general;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::consorcio TO administrativo_general;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::gastos TO administrativo_general;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::expensas TO administrativo_general;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Pago TO administrativo_general;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Externos TO administrativo_general;
DENY ALTER ON DATABASE::Com5600G07 TO administrativo_general; 



-------------------------------------------------
--			 								   --
--		    Administrativo Bancario            --
--											   --
-------------------------------------------------
-- Acutualizacion de datos de UF: NO
-- Importacion de informacion Bancaria: SI
-- Generacion de reportes : SI
------------------------------------------------

-------------------------------------------------
--             Actualizacion datos UF          --
-------------------------------------------------

DENY EXECUTE ON ImportarConsorciosDesdeExcel TO administrativo_bancario;
DENY EXECUTE ON consorcio.importarunidadesfuncionales TO administrativo_bancario;
DENY EXECUTE ON consorcio.importarPersonas TO administrativo_bancario;
DENY EXECUTE ON consorcio.importarocupaciones TO administrativo_bancario;
DENY EXECUTE ON gastos.Sp_CargarGastosDesdeArchivo TO administrativo_bancario;

-------------------------------------------------
--     Importacion de informacion bancaria     --
-------------------------------------------------

GRANT EXECUTE ON Pago.sp_importarPagosDesdeCSV  TO administrativo_general;

-------------------------------------------------
--          Generacion de Reportes             --
-------------------------------------------------

GRANT EXECUTE ON SCHEMA::report TO administrativo_general;

-------------------------------------------------
--             Permisos generales              --
-------------------------------------------------
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::report TO administrativo_bancario;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::consorcio TO administrativo_bancario;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::gastos TO administrativo_bancario;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::expensas TO administrativo_bancario;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Pago TO administrativo_bancario;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Externos TO administrativo_bancario;
DENY ALTER ON DATABASE::Com5600G07 TO administrativo_bancario; 

-------------------------------------------------
--			 								   --
--		    Administrativo Operativo           --
--											   --
-------------------------------------------------
-- Acutualizacion de datos de UF: SI
-- Importacion de informacion Bancaria: NO
-- Generacion de reportes : SI
------------------------------------------------
-------------------------------------------------
--             Actualizacion datos UF          --
-------------------------------------------------

GRANT EXECUTE ON ImportarConsorciosDesdeExcel TO administrativo_operativo;
GRANT EXECUTE ON consorcio.importarunidadesfuncionales TO administrativo_operativo;
GRANT EXECUTE ON consorcio.importarPersonas TO administrativo_operativo;
GRANT EXECUTE ON consorcio.importarocupaciones TO administrativo_operativo;
GRANT EXECUTE ON gastos.Sp_CargarGastosDesdeArchivo TO administrativo_operativo;

-------------------------------------------------
--     Importacion de informacion bancaria     --
-------------------------------------------------

DENY EXECUTE ON Pago.sp_importarPagosDesdeCSV  TO administrativo_operativo;

-------------------------------------------------
--          Generacion de Reportes             --
-------------------------------------------------

GRANT EXECUTE ON SCHEMA::report TO administrativo_operativo;

-------------------------------------------------
--             Permisos generales              --
-------------------------------------------------
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::report TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::consorcio TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::gastos TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::expensas TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Pago TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Externos TO administrativo_operativo;
DENY ALTER ON DATABASE::Com5600G07 TO administrativo_operativo; 

-------------------------------------------------
--			 								   --
--		           SISTEMAS                    --
--											   --
-------------------------------------------------
-- Acutualizacion de datos de UF: NO
-- Importacion de informacion Bancaria: NO
-- Generacion de reportes : SI
------------------------------------------------
-------------------------------------------------
--             Actualizacion datos UF          --
-------------------------------------------------

DENY EXECUTE ON ImportarConsorciosDesdeExcel TO sistemas;
DENY EXECUTE ON consorcio.importarunidadesfuncionales TO sistemas;
DENY EXECUTE ON consorcio.importarPersonas TO sistemas;
DENY EXECUTE ON consorcio.importarocupaciones TO sistemas;
DENY EXECUTE ON gastos.Sp_CargarGastosDesdeArchivo TO sistemas;

-------------------------------------------------
--     Importacion de informacion bancaria     --
-------------------------------------------------

DENY EXECUTE ON Pago.sp_importarPagosDesdeCSV  TO sistemas;

-------------------------------------------------
--          Generacion de Reportes             --
-------------------------------------------------

GRANT EXECUTE ON SCHEMA::report TO administrativo_operativo;

-------------------------------------------------
--             Permisos generales              --
-------------------------------------------------
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::report TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::consorcio TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::gastos TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::expensas TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Pago TO administrativo_operativo;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Externos TO administrativo_operativo;
DENY ALTER ON DATABASE::Com5600G07 TO administrativo_operativo; 

-------------------------------------------------
--											   --
--			CREACION DE USUARIOS      	       --
--											   --
-------------------------------------------------
-------------------------------------------------
-- Documentación:
-- Los usuarios se crean SIN LOGIN porque
-- funcionan como identificadores lógicos para
-- permisos internos. No están vinculados a
-- autenticación del servidor SQL.
------------------------------------------------

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'usuario_administrador_general')
    CREATE USER usuario_administrador_general WITHOUT LOGIN;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'usuario_administrador_bancario')
    CREATE USER usuario_administrador_bancario WITHOUT LOGIN;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'usuario_administrador_operativo')
    CREATE USER usuario_administrador_operativo WITHOUT LOGIN;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'usuario_sistemas')
    CREATE USER usuario_sistemas WITHOUT LOGIN;

-------------------------------------------------
--											   --
--			    ASIGNAR USUARIOS          	   --
--											   --
-------------------------------------------------


ALTER ROLE administrativo_general ADD MEMBER usuario_administrador_general;
ALTER ROLE administrativo_bancario ADD MEMBER usuario_administrador_bancario;
ALTER ROLE administrativo_operativo ADD MEMBER usuario_administrador_operativo;
ALTER ROLE sistemas ADD MEMBER usuario_sistemas;
GO

/*Test
.
.
SELECT name as Nombre_rol from sys.database_principals where type='R' order by name;
.
.*/
-------------------------------------------------
--											   --
--			REMOVER MIEMBROS DE ROLES  	       --
--											   --
-------------------------------------------------
-- Nota final:
-- Esta sección permite revertir todos los 
-- cambios, eliminando miembros y roles en caso
-- de recreación del entorno de desarrollo.
-------------------------------------------------

/*IF DATABASE_PRINCIPAL_ID('administrativo_general') IS NOT NULL
BEGIN
    ALTER ROLE administrativo_general DROP MEMBER usuario_administrador_general;
    DROP ROLE administrativo_general;
END

IF DATABASE_PRINCIPAL_ID('administrativo_bancario') IS NOT NULL
BEGIN
    ALTER ROLE administrativo_bancario DROP MEMBER usuario_administrador_bancario;
    DROP ROLE administrativo_bancario;
END

IF DATABASE_PRINCIPAL_ID('administrativo_operativo') IS NOT NULL
BEGIN
    ALTER ROLE administrativo_operativo DROP MEMBER usuario_administrador_operativo;
    DROP ROLE administrativo_operativo;
END

IF DATABASE_PRINCIPAL_ID('sistemas') IS NOT NULL
BEGIN
    ALTER ROLE sistemas DROP MEMBER usuario_sistemas;
    DROP ROLE sistemas;
END
GO*/

-------------------------------------------------
--                                               --
--         PRUEBAS DE PERMISOS POR ROL          --
--                                               --
-------------------------------------------------
-- En esta sección se validan las capacidades de
-- cada rol utilizando EXECUTE AS USER, lo cual
-- simula el contexto del usuario sin login.
-- Para volver al usuario original se debe usar REVERT.
-------------------------------------------------


/***********************************************
 *  PRUEBA 1 — ADMINISTRATIVO GENERAL
 ***********************************************/
/*PRINT '===== PRUEBA: ADMINISTRATIVO GENERAL =====';
EXECUTE AS USER = 'usuario_administrador_general';

--  Debe Poder: Actualizar datos de UF
PRINT 'Prueba: Ejecutar ImportarConsorciosDesdeExcel';
BEGIN TRY
    EXEC ImportarConsorciosDesdeExcel 
         @RutaArchivo = 'D:\BDA 2C2025\archivostp\datos varios.xlsx',
        @NombreHoja = N'Consorcios';
    PRINT 'OK: Puede ejecutar ImportarConsorciosDesdeExcel';
END TRY
BEGIN CATCH
    PRINT 'ERROR inesperado en ImportarConsorciosDesdeExcel: ' + ERROR_MESSAGE();
END CATCH;

--  No Debe Poder: Importación bancaria
PRINT 'Prueba: Ejecutar sp_importarPagosDesdeCSV (DEBE FALLAR)';
BEGIN TRY
    EXEC Pago.sp_importarPagosDesdeCSV 
    @rutaArchivo = 'D:\BDA 2C2025\archivostp\pagos_consorcios.csv'
    PRINT 'ERROR: NO deberia poder ejecutar sp_importarPagosDesdeCSV';
END TRY
BEGIN CATCH
    PRINT 'OK: Acceso denegado correctamente → ' + ERROR_MESSAGE();
END CATCH;

--  Debe Poder: Generación de reportes
PRINT 'Prueba: Ejecutar SP dentro de report (si existe alguno)';
BEGIN TRY
    EXEC EXEC report.sp_ReporteTopMeses @IdConsorcio = 4, @Anio = 2025;
    PRINT 'OK: Puede acceder a reportes';
END TRY
BEGIN CATCH
    PRINT 'Advertencia: No se encontró SP para probar reportes';
END CATCH;

REVERT;  -- Regresar al usuario actual
PRINT '===== FIN PRUEBA ADMINISTRATIVO GENERAL =====';



/***********************************************
 *  PRUEBA 2 — ADMINISTRATIVO BANCARIO
 ***********************************************/
PRINT '===== PRUEBA: ADMINISTRATIVO BANCARIO =====';
EXECUTE AS USER = 'usuario_administrador_bancario';

--  No puede actualizar UF
PRINT 'Prueba: Ejecutar ImportarConsorciosDesdeExcel (DEBE FALLAR)';
BEGIN TRY
    EXEC ImportarConsorciosDesdeExcel 
         @RutaArchivo = 'D:\BDA 2C2025\archivostp\datos varios.xlsx',
         @NombreHoja = N'Consorcios';
    PRINT 'ERROR: NO deberia poder ejecutar ImportarConsorciosDesdeExcel';
END TRY
BEGIN CATCH
    PRINT 'OK: Acceso denegado correctamente → ' + ERROR_MESSAGE();
END CATCH;

--  Sí puede importar pagos
PRINT 'Prueba: Ejecutar sp_importarPagosDesdeCSV';
BEGIN TRY
    EXEC Pago.sp_importarPagosDesdeCSV 
    @rutaArchivo = 'D:\BDA 2C2025\archivostp\pagos_consorcios.csv'
    PRINT 'OK: Puede ejecutar sp_importarPagosDesdeCSV';
END TRY
BEGIN CATCH
    PRINT 'ERROR inesperado en sp_importarPagosDesdeCSV: ' + ERROR_MESSAGE();
END CATCH;

--  Puede generar reportes
PRINT 'Prueba: Ejecución de SP de reportes';
BEGIN TRY
    EXEC EXEC report.sp_ReporteTopMeses @IdConsorcio = 4, @Anio = 2025;
    PRINT 'OK: Puede generar reportes';
END TRY
BEGIN CATCH
    PRINT 'Advertencia: SP de report no encontrado.';
END CATCH;

REVERT;
PRINT '===== FIN PRUEBA ADMINISTRATIVO BANCARIO =====';



/***********************************************
 *  PRUEBA 3 — ADMINISTRATIVO OPERATIVO
 ***********************************************/
PRINT '===== PRUEBA: ADMINISTRATIVO OPERATIVO =====';
EXECUTE AS USER = 'usuario_administrador_operativo';

-- Puede actualizar UF
PRINT 'Prueba: Ejecutar ImportarConsorciosDesdeExcel';
BEGIN TRY
    EXEC ImportarConsorciosDesdeExcel 
         @RutaArchivo = 'D:\BDA 2C2025\archivostp\datos varios.xlsx',
        @NombreHoja = N'Consorcios';
    PRINT 'OK: Puede ejecutar ImportarConsorciosDesdeExcel';
END TRY
BEGIN CATCH
    PRINT 'ERROR inesperado: ' + ERROR_MESSAGE();
END CATCH;

--  No puede importar pagos bancarios
PRINT 'Prueba: Ejecutar sp_importarPagosDesdeCSV (DEBE FALLAR)';
BEGIN TRY
    EXEC Pago.sp_importarPagosDesdeCSV 
    @rutaArchivo = 'D:\BDA 2C2025\archivostp\pagos_consorcios.csv'
    PRINT 'ERROR: No deberia poder importar pagos';
END TRY
BEGIN CATCH
    PRINT 'OK: Acceso denegado correctamente → ' + ERROR_MESSAGE();
END CATCH;

-- Puede generar reportes
PRINT 'Prueba: Ejecutar reportes';
BEGIN TRY
    EXEC EXEC report.sp_ReporteTopMeses @IdConsorcio = 4, @Anio = 2025;
    PRINT 'OK: Puede acceder a reportes';
END TRY
BEGIN CATCH
    PRINT 'Advertencia: No existe SP de reportes.';
END CATCH;

REVERT;
PRINT '===== FIN PRUEBA ADMINISTRATIVO OPERATIVO =====';



/***********************************************
 *  PRUEBA 4 — SISTEMAS
 ***********************************************/
PRINT '===== PRUEBA: SISTEMAS =====';
EXECUTE AS USER = 'usuario_sistemas';

--  No puede actualizar UF
PRINT 'Prueba: Ejecutar ImportarConsorciosDesdeExcel (DEBE FALLAR)';
BEGIN TRY
    EXEC ImportarConsorciosDesdeExcel 
    @RutaArchivo = 'D:\BDA 2C2025\archivostp\datos varios.xlsx',
    @NombreHoja = N'Consorcios';
    PRINT 'ERROR: NO deberia poder ejecutar ImportarConsorciosDesdeExcel';
END TRY
BEGIN CATCH
    PRINT 'OK: Acceso denegado → ' + ERROR_MESSAGE();
END CATCH;

--  No puede importar pagos
PRINT 'Prueba: Ejecutar sp_importarPagosDesdeCSV (DEBE FALLAR)';
BEGIN TRY
    EXEC Pago.sp_importarPagosDesdeCSV 
    @rutaArchivo = 'D:\BDA 2C2025\archivostp\pagos_consorcios.csv'
    PRINT 'ERROR: NO debería poder ejecutar sp_importarPagosDesdeCSV';
END TRY
BEGIN CATCH
    PRINT 'OK: Acceso denegado → ' + ERROR_MESSAGE();
END CATCH;

--  Puede generar reportes
PRINT 'Prueba: Ejecutar reportes';
BEGIN TRY
    EXEC EXEC report.sp_ReporteTopMeses @IdConsorcio = 4, @Anio = 2025;
    PRINT 'OK: Puede generar reportes';
END TRY
BEGIN CATCH
    PRINT 'Advertencia: No existe SP de reportes para probar.';
END CATCH;

REVERT;
PRINT '===== FIN PRUEBA SISTEMAS =====';*/