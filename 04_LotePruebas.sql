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
    @RutaArchivo = 'C:\Archivos_para_el_TP\datos varios.xlsx',
    @NombreHoja = N'Consorcios';
---------------------------------------------------------------------
--											                       --
--			 TABLA UNIDAD FUNCIONAL, BAULERA Y COCHERA      	   --
--											                       --
---------------------------------------------------------------------
EXEC consorcio.importarunidadesfuncionales 
     @rutaarch = 'C:\Archivos_para_el_TP\uf por consorcio.txt'
-------------------------------------------------
--											   --
--			    TABLA PERSONAS      	       --
--											   --
-------------------------------------------------
EXEC consorcio.importarPersonas 
    @rutaArchPersonas = 'C:\Archivos_para_el_TP\inquilino-propietarios-datos.csv', 
    @rutaArchUF = 'C:\Archivos_para_el_TP\inquilino-propietarios-UF.csv'
-------------------------------------------------
--											   --
--			    TABLA OCUPACION      	       --
--											   --
-------------------------------------------------
exec consorcio.importarocupaciones	
	@rutaarchpersonas = 'C:\Archivos_para_el_TP\inquilino-propietarios-datos.csv',
	@rutaarchuf = 'C:\Archivos_para_el_TP\inquilino-propietarios-uf.csv';
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
    @RutaArchivoJSON = 'C:\Archivos_para_el_TP\Servicios.Servicios.json',
    @RutaArchivoExcel = 'C:\Archivos_para_el_TP\datos varios.xlsx',
    @Anio = 2025,
    @DiaVto1 = 10,
    @DiaVto2 = 20;    

-------------------------------------------------
--											   --
--		    TABLA PAGOS Y PRORRATEO     	   --
--											   --
-------------------------------------------------
EXEC Pago.sp_importarPagosDesdeCSV 
    @rutaArchivo = 'C:\Archivos_para_el_TP\pagos_consorcios.csv'


---------------------------------REPORTES-----------------------------------

-------------------------------------------------
--											   --
--		       FLUJO CAJA SEMANAL              --
--											   --
-------------------------------------------------

EXEC report.sp_ReporteFlujoCajaSemanal
    @FechaInicio = '2025-01-01', 
    @FechaFin = '2025-12-31', 
    @IdConsorcio = 4; -- Poner num de consorcio para realizar el reporte


-------------------------------------------------
--											   --
--		       RECAUDACION MENSUAL             --
--					 CRUZADA				   --
--                                             --
-------------------------------------------------

EXEC report.sp_ReporteRecaudacionMensual
    @IdConsorcio = 4, 
    @Anio = 2025;


-------------------------------------------------
--											   --
--		       RECAUDACION POR                 --
--				 PROCEDENCIA			       --
--                                             --
-------------------------------------------------

--EN ESTE SP UTILIZAMOS FORMATOXML PARA DARLE OPCION DE DEVOLVER LA EJECUCION EN FORMATO XML TAL COMO SOLICITA LA CONSIGNA

-- Como output normal
EXEC report.sp_ReporteRecaudacionProcedencia @IdConsorcio = 4, @Anio = 2025, @FormatoXML = 0;

-- Formato XML
EXEC report.sp_ReporteRecaudacionProcedencia @IdConsorcio = 4, @Anio = 2025, @FormatoXML = 1;

-------------------------------------------------
--											   --
--		    TOP 5 INGRESOS Y GASTOS            --
--                                             --
-------------------------------------------------

EXEC report.sp_ReporteTopMeses @IdConsorcio = 2, @Anio = 2025;

-------------------------------------------------
--											   --
--		         TOP 3 MOROSOS                 --
--                                             --
-------------------------------------------------

--EN ESTE SP UTILIZAMOS FORMATOXML PARA DARLE OPCION DE DEVOLVER LA EJECUCION EN FORMATO XML TAL COMO SOLICITA LA CONSIGNA

-- Como output normal
EXEC report.sp_ReporteTopMorosos @IdConsorcio = 5, @FormatoXML = 0;


-- Formato XML
EXEC report.sp_ReporteTopMorosos @IdConsorcio = 2, @FormatoXML = 1;

-------------------------------------------------
--											   --
--		      DIF DIAS ENTRE PAGOS             --
--                                             --
-------------------------------------------------

--Probamos

-- Ver el historial completo
EXEC report.sp_ReporteDiasEntrePagos @IdConsorcio = 4; 

-- ver solo un periodo especifico
EXEC report.sp_ReporteDiasEntrePagos 
    @IdConsorcio = 3, 
    @FechaInicio = '2025-01-01', 
    @FechaFin = '2025-12-31';

select * from Pago.Pago p  order  by  p.Fecha desc

-------------------------------------------------
--											   --
--		    REPORTES VIA MAIL (API)            --
--                                             --
-------------------------------------------------
--Se utilizo el reporte generado en el reporte 5 con el objetivo de simular una comunicacion con el estudio juridico para informar morosos

EXEC report.sp_EnviarReportePorEmail 
    @IdConsorcio = 5, 
    @EmailDestino = 'agustinpe45@gmail.com'; --aca ponemos el mail al que queremos mandar el reporte (se puede usar cualquiera)
                                             --simulando el contacto con el estudio juridico
