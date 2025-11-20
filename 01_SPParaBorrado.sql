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
--		   CREACION DE STORED PROCEDURED	   --
--				  PARA BORRADO			       --
-------------------------------------------------

Use master

USE Com5600G07
GO

-------------------------------------------------
--											   --
--		        BORRAR UNIDAD				   --
--				  FUNCIONAL					   --
--											   --			
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_BorrarUnidadFuncional
	@IdUF int
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
		BEGIN
			IF EXISTS(SELECT 1 FROM expensas.Prorrateo WHERE IdUF = @IdUF)
				OR
			EXISTS(SELECT 1 FROM Pago.Pago WHERE IdUF = @IdUF)
			BEGIN
				PRINT('no se puede borrar la Unidad Funcional debido a Pagos o Prorrateos pendientes.')
				RAISERROR('La UF no puede ser borrada debido a historial de Pagos o Prorrateos.', 10, 1);
			
			END
			ELSE
			BEGIN
				DELETE FROM consorcio.Baulera WHERE IdUF = @IdUF;
				DELETE FROM consorcio.Cochera WHERE IdUF = @IdUF;
				DELETE FROM consorcio.Ocupacion WHERE IdUF = @IdUF;
				

				DELETE FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF;

				PRINT('La Unidad Funcional ' + CAST(@IdUF AS VARCHAR) + ' se borro con exito.');

			END
		END
		ELSE
		BEGIN
			PRINT('No existe la Unidad Funcional solicitada.');
			RAISERROR('No existe la Unidad Funcional', 10, 1);

		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP consorcio.sp_BorrarUnidadFuncional: ' + ERROR_MESSAGE());
			if @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en el borrado de Unidad Funcional', 16, 1);

		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP consorcio.sp_BorrarUnidadFuncional: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;

		END

	END CATCH

END
GO
-------------------------------------------------
--											   --
--		        BORRAR PERSONA                 --
--											   --
-------------------------------------------------	
CREATE OR ALTER PROCEDURE consorcio.sp_BorrarPersona
	@DNI VARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM consorcio.Persona WHERE DNI = @DNI)
		BEGIN

			IF EXISTS(SELECT 1 FROM consorcio.Ocupacion WHERE DNI = @DNI)
			BEGIN

				PRINT('No se puede borrar a la Persona debido a que esta asignada a una o mas unidades.');
				RAISERROR('La Persona esta en uso y no puede ser borrada.', 10, 1);

			END
			ELSE
			BEGIN
				DELETE FROM consorcio.Persona WHERE DNI = @DNI;
				PRINT('Persona con DNI ' + @DNI + ' borrada exitosamente.');

				END
			END
			ELSE
			BEGIN
				PRINT('No existe la Persona con DNI ' + @DNI);
				RAISERROR('No existe la Persona con ese DNI', 10, 1);

			END

			COMMIT TRANSACTION;

		END TRY
		BEGIN CATCH
			IF ERROR_SEVERITY() > 10
			BEGIN
				PRINT('Error en el SP consorcio.sp_BorrarPersona: ' + ERROR_MESSAGE());
				IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
				RAISERROR('ERROR en el borrado de Persona', 16, 1);

			END
			IF ERROR_SEVERITY() = 10
			BEGIN
				PRINT('Advertencia en SP consorcio.sp_BorrarPersona: ' + ERROR_MESSAGE());

				COMMIT TRANSACTION;

			END

		END CATCH
END
GO
-------------------------------------------------
--											   --
--		        BORRAR EXPENSA                 --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_BorrarExpensa
	@NroExpensa INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM expensas.Expensa WHERE NroExpensa = @NroExpensa)
		BEGIN
			DELETE FROM expensas.Prorrateo
			WHERE NroExpensa = @NroExpensa;


			DELETE FROM expensas.Expensa
			WHERE NroExpensa = @NroExpensa;

		END

		ELSE
		BEGIN
			PRINT('No existe la Expensa');
			RAISERROR('No existe la Expensa', 10, 1);

		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP expensas.sp_BorrarExpensas: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en borrado de expensa', 16, 1);

		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP expensas.sp_BorrarExpensa: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;

		END

	END CATCH

END
GO
-------------------------------------------------
--											   --
--		        BORRAR GASTO                   --			      
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_BorrarGasto
	@IdGasto INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM gastos.Gasto WHERE idGasto = @IdGasto)
		BEGIN
			-- Borrar de la tabla específica (Ordinario o Extraordinario)
			IF EXISTS(SELECT 1 FROM gastos.Gasto_Ordinario WHERE idGasto = @IdGasto)
			BEGIN
				DELETE FROM gastos.Gasto_Ordinario WHERE idGasto = @IdGasto;
				PRINT('Gasto Ordinario eliminado de tabla específica.');
			END
			
			IF EXISTS(SELECT 1 FROM gastos.Gasto_Extraordinario WHERE idGasto = @IdGasto)
			BEGIN
				DELETE FROM gastos.Gasto_Extraordinario WHERE idGasto = @IdGasto;
				PRINT('Gasto Extraordinario eliminado de tabla específica.');
			END

			-- Borrar de la tabla principal
			DELETE FROM gastos.Gasto WHERE idGasto = @IdGasto;
			PRINT('Gasto ' + CAST(@IdGasto AS VARCHAR) + ' borrado completamente.');

		END
		ELSE
		BEGIN
			PRINT('No existe el Gasto con ID: ' + CAST(@IdGasto AS VARCHAR));
			RAISERROR('No existe el Gasto', 10, 1);
		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP gastos.sp_BorrarGastoCompleto: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en el borrado completo de Gasto', 16, 1);
		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP gastos.sp_BorrarGastoCompleto: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;
		END
	END CATCH
END
GO
-------------------------------------------------
--											   --
--		        BORRAR PAGO                    --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE Pago.sp_BorrarPago
	@IdPago INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM Pago.Pago WHERE IdPago = @IdPago)
		BEGIN
			DELETE FROM Pago.Pago
			WHERE IdPago = @IdPago;

		END

		ELSE
		BEGIN
			PRINT('No existe el Pago con ID: ' + CAST(@IdPago AS VARCHAR));
			RAISERROR('No existe el Pago', 10, 1);

		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP Pago.sp_BorrarPago: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en borrado de Pago', 16, 1);

		END

		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP Pago.sp_BorrarPago: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;

		END

	END CATCH

END
GO

-------------------------------------------------
--											   --
--		        BORRAR CONSORCIO               --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_BorrarConsorcio
	@IdConsorcio INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
		BEGIN
			-- Eliminar gastos asociados al consorcio
			DELETE FROM gastos.Gasto WHERE idConsorcio = @IdConsorcio;

			-- Eliminar expensas y sus dependencias
			DELETE FROM expensas.Prorrateo 
			WHERE NroExpensa IN (SELECT nroExpensa FROM expensas.Expensa WHERE idConsorcio = @IdConsorcio);
			
			DELETE FROM Pago.Pago 
			WHERE NroExpensa IN (SELECT nroExpensa FROM expensas.Expensa WHERE idConsorcio = @IdConsorcio);
			
			DELETE FROM gastos.Gasto 
			WHERE nroExpensa IN (SELECT nroExpensa FROM expensas.Expensa WHERE idConsorcio = @IdConsorcio);
			
			DELETE FROM expensas.Expensa WHERE idConsorcio = @IdConsorcio;

			-- Eliminar unidades funcionales y sus dependencias
			DELETE FROM consorcio.Baulera 
			WHERE IdUF IN (SELECT IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsorcio);
			
			DELETE FROM consorcio.Cochera 
			WHERE IdUF IN (SELECT IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsorcio);
			
			DELETE FROM consorcio.Ocupacion 
			WHERE IdUF IN (SELECT IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsorcio);
			
			-- Actualizar personas que referencian UFs que van a ser eliminadas
			UPDATE consorcio.Persona 
			SET idUF = NULL 
			WHERE idUF IN (SELECT IdUF FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsorcio);
			
			DELETE FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsorcio;

			-- Finalmente eliminar el consorcio
			DELETE FROM consorcio.Consorcio
			WHERE IdConsorcio = @IdConsorcio;

			PRINT('Consorcio ' + CAST(@IdConsorcio AS VARCHAR) + ' borrado exitosamente.');

		END
		ELSE
		BEGIN
			PRINT('No existe el Consorcio');
			RAISERROR('No existe el Consorcio', 10, 1);
		END

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP consorcio.sp_BorrarConsorcio: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en el borrado de consorcio', 16, 1);
		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP consorcio.sp_BorrarConsorcio: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;
		END
	END CATCH
END
GO
-------------------------------------------------
--											   --
--		        BORRAR PRORRATEO               --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_BorrarProrrateo
    @IdProrrateo INT,
    @IdUF INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM expensas.Prorrateo WHERE IdProrrateo = @IdProrrateo AND IdUF = @IdUF)
		BEGIN
			DELETE FROM expensas.Prorrateo
			WHERE IdProrrateo = @IdProrrateo AND IdUF = @IdUF;

            PRINT('Prorrateo ' + CAST(@IdProrrateo AS VARCHAR) + ' para UF ' + CAST(@IdUF AS VARCHAR) + ' borrado exitosamente.');

		END
		ELSE
		BEGIN
			PRINT('No existe el Prorrateo especificado');
			RAISERROR('No existe el Prorrateo', 10, 1);
		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP expensas.sp_BorrarProrrateo: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en el borrado de Prorrateo', 16, 1);
		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP expensas.sp_BorrarProrrateo: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;
		END
	END CATCH
END
GO

-------------------------------------------------
--											   --
--		        BORRAR OCUPACION               --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_BorrarOcupacion
	@IdOcupacion INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM consorcio.Ocupacion WHERE Id_Ocupacion = @IdOcupacion)
		BEGIN
			DELETE FROM consorcio.Ocupacion
			WHERE Id_Ocupacion = @IdOcupacion;

			PRINT('Ocupación ' + CAST(@IdOcupacion AS VARCHAR) + ' borrada exitosamente.');
		END
		ELSE
		BEGIN
			PRINT('No existe la Ocupación');
			RAISERROR('No existe la Ocupación', 10, 1);
		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP consorcio.sp_BorrarOcupacion: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en el borrado de Ocupación', 16, 1);
		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP consorcio.sp_BorrarOcupacion: ' + ERROR_MESSAGE());
			COMMIT TRANSACTION;
		END
	END CATCH
END
GO
