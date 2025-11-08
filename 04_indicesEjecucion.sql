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
----------------------------------------------------------------
--											                  --
--			     INDICES PARA OPTIMIZAR CONSULTAS             --
--															  --
----------------------------------------------------------------
--NO DECLARE TODOS LOS INDICES, SOLO CARGUE A SU BASE DE DATOS LOS QUE NECESITE Y USE FRECUENTEMENTE
--TENER INDICES SIN USAR EMPEORA LA PERFORMANCE DE LA BDD
-------------------------------------------------
--											   --
--			    TABLA CONSORCIOS      	       --
--											   --
-------------------------------------------------
CREATE NONCLUSTERED INDEX IX_Consorcio_Nombre ON consorcio.Consorcio (NombreConsorcio);
CREATE NONCLUSTERED INDEX IX_Consorcio_Direccion ON consorcio.Consorcio (Direccion);
-------------------------------------------------
--											   --
--			 TABLA UNIDAD FUNCIONAL      	   --
--											   --
-------------------------------------------------
CREATE NONCLUSTERED INDEX IX_UnidadFuncional_Consorcio ON consorcio.UnidadFuncional (IdConsorcio);
CREATE NONCLUSTERED INDEX IX_UnidadFuncional_PisoDepto ON consorcio.UnidadFuncional (Piso, Depto);
CREATE NONCLUSTERED INDEX IX_UnidadFuncional_Coeficiente ON consorcio.UnidadFuncional (Coeficiente);
-------------------------------------------------
--											   --
--			    TABLA PERSONA      	           --
--											   --
-------------------------------------------------
CREATE NONCLUSTERED INDEX IX_Persona_UF ON consorcio.Persona (idUF);
CREATE NONCLUSTERED INDEX IX_Persona_CVU ON consorcio.Persona (CVU);
CREATE NONCLUSTERED INDEX IX_Persona_ApellidoNombre ON consorcio.Persona (Apellido, Nombre);
CREATE NONCLUSTERED INDEX IX_Persona_Email ON consorcio.Persona (Email) WHERE Email IS NOT NULL;
-------------------------------------------------
--											   --
--			    TABLA OCUPACION      	       --
--											   --
-------------------------------------------------
CREATE NONCLUSTERED INDEX IX_Ocupacion_UF ON consorcio.Ocupacion (IdUF);
CREATE NONCLUSTERED INDEX IX_Ocupacion_DNI ON consorcio.Ocupacion (DNI);
CREATE NONCLUSTERED INDEX IX_Ocupacion_Rol ON consorcio.Ocupacion (Rol);
CREATE UNIQUE NONCLUSTERED INDEX IX_Ocupacion_UF_DNI ON consorcio.Ocupacion (IdUF, DNI);
-------------------------------------------------
--											   --
--			     TABLA BAULERA      	       --
--											   --
-------------------------------------------------
CREATE NONCLUSTERED INDEX IX_Baulera_UF ON consorcio.Baulera (IdUF);
CREATE NONCLUSTERED INDEX IX_Baulera_Tamanio ON consorcio.Baulera (Tamanio);
-------------------------------------------------
--											   --
--			     TABLA COCHERA      	       --
--											   --
-------------------------------------------------
CREATE NONCLUSTERED INDEX IX_Cochera_UF ON consorcio.Cochera (IdUF);
CREATE NONCLUSTERED INDEX IX_Cochera_Tamanio ON consorcio.Cochera (Tamanio);