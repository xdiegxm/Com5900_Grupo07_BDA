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
    @RutaArchivo = 'C:\archivos_para_el_TP\datos varios.xlsx',
    @NombreHoja = N'Consorcios';
---------------------------------------------------------------------
--											                       --
--			 TABLA UNIDAD FUNCIONAL, BAULERA Y COCHERA      	   --
--											                       --
---------------------------------------------------------------------
EXEC consorcio.importarunidadesfuncionales 
     @rutaarch = 'C:\archivos_para_el_TP\uf por consorcio.txt'
-------------------------------------------------
--											   --
--			    TABLA PERSONAS      	       --
--											   --
-------------------------------------------------
EXEC consorcio.importarPersonas 
    @rutaArchPersonas = 'C:\archivos_para_el_TP\inquilino-propietarios-datos.csv', 
    @rutaArchUF = 'C:\archivos_para_el_TP\inquilino-propietarios-UF.csv'
-------------------------------------------------
--											   --
--			    TABLA OCUPACION      	       --
--											   --
-------------------------------------------------
exec consorcio.importarocupaciones	
	@rutaarchpersonas = 'C:\archivos_para_el_TP\inquilino-propietarios-datos.csv',
	@rutaarchuf = 'C:\archivos_para_el_TP\inquilino-propietarios-uf.csv';

-------------------------------------------------
--											   --
--		    TABLA EXPENSA Y GASTOS     	       --
--											   --
-------------------------------------------------
EXEC gastos.Sp_CargarGastosDesdeArchivo 
    @RutaArchivoJSON = 'C:\Archivos_para_el_TP\Servicios.Servicios.json',
    @RutaArchivoExcel = 'C:\Archivos_para_el_TP\datos varios.xlsx',
    @Anio = 2025,
    @DiaVto1 = 10,
    @DiaVto2 = 20;    
-------------------------------------------------
--											   --
--		         TABLA PAGOS     	           --
--											   --
-------------------------------------------------
EXEC Pago.sp_importarPagosDesdeCSV @rutaArchivo = 'C:\Archivos_para_el_TP\pagos_consorcios.csv'

select * from Pago.Pago

select * from expensas.Prorrateo
where PagosRecibidos != 0

select * from gastos.Gasto
select * from gastos.Gasto_Extraordinario
select * from gastos.Gasto_Ordinario
