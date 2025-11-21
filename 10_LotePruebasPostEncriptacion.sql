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
--			     LOTE DE PRUEBAS      	       --
--											   --
-------------------------------------------------
--Los EXEC deben hacerse con las referencias que tenga cada uno a sus archivos.
--EJECUTELOS EN ORDEN
USE Com5600G07
GO
-------------------------------------------------
--											   --
--			    TABLA CONSORCIOS      	       --
--											   --
-------------------------------------------------
EXEC ImportarConsorciosDesdeExcel 
    @RutaArchivo = 'D:\BDA 2C2025\archivostp\datos varios.xlsx',
    @NombreHoja = N'Consorcios';
---------------------------------------------------------------------
--											                       --
--			 TABLA UNIDAD FUNCIONAL, BAULERA Y COCHERA      	   --
--											                       --
---------------------------------------------------------------------
EXEC consorcio.importarunidadesfuncionales 
     @rutaarch = 'D:\BDA 2C2025\archivostp\uf por consorcio.txt'
-------------------------------------------------
--											   --
--			    TABLA PERSONAS      	       --
--											   --
-------------------------------------------------
EXEC consorcio.importarPersonas 
    @rutaArchPersonas = 'D:\BDA 2C2025\archivostp\inquilino-propietarios-datos.csv', 
    @rutaArchUF = 'D:\BDA 2C2025\archivostp\inquilino-propietarios-UF.csv'
-------------------------------------------------
--											   --
--			    TABLA OCUPACION      	       --
--											   --
-------------------------------------------------
exec consorcio.importarocupaciones	
	@rutaarchpersonas = 'D:\BDA 2C2025\archivostp\inquilino-propietarios-datos.csv',
	@rutaarchuf = 'D:\BDA 2C2025\archivostp\inquilino-propietarios-uf.csv';
-------------------------------------------------
--											   --
--		    TABLA EXPENSA Y GASTOS     	       --
--											   --
-------------------------------------------------

-- 1. Habilitar las opciones avanzadas
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- 2. Habilitar las consultas distribuidas Ad Hoc
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- 3. Permitir que el proveedor ACE se ejecute "In-Process" (Dentro del proceso de SQL)
-- ESTA ES LA CLAVE
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1
GO

-- 4. (Opcional, pero recomendado) Habilitar parámetros dinámicos
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'DynamicParameters', 1
GO

EXEC gastos.Sp_CargarGastosDesdeArchivo 
    @RutaArchivoJSON = 'D:\BDA 2C2025\archivostp\Servicios.Servicios.json',
    @RutaArchivoExcel = 'D:\BDA 2C2025\archivostp\datos varios.xlsx',
    @Anio = 2025,
    @DiaVto1 = 10,
    @DiaVto2 = 20;    
-------------------------------------------------
--											   --
--		    TABLA PAGOS Y PRORRATEO     	   --
--											   --
-------------------------------------------------
EXEC Pago.sp_importarPagosDesdeCSV 
    @rutaArchivo = 'D:\BDA 2C2025\archivostp\pagos_consorcios.csv'

select * from Pago.Pago