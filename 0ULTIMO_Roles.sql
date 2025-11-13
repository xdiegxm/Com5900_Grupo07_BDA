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

IF DATABASE_PRINCIPAL_ID('administrativo_general') IS NOT NULL
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
GO

