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

			WHILE EXISTS(SELECT 1 FROM expensas.Expensa WHERE IdConsorcio = @IdConsorcio)
			BEGIN
				DECLARE @TmpTipo CHAR(1), @TmpNro INT;

				SELECT TOP 1 @TmpTipo = Tipo, @TmpNro = NroExpensa
				FROM expensas.Expensa
				WHERE IdConsorcio = @IdConsorcio;

				PRINT('Borrando Expensa ' + @TmpTipo + '-' + CAST(@TmpNro AS VARCHAR));
				EXEC expensas.sp_BorrarExpensa
					@Tipo = @TmpTipo,
					@NroExpensa = @TmpNro;

			END

			WHILE EXISTS(SELECT 1 FROM consorcio.UnidadFuncional WHERE IdConsorcio = @IdConsorcio)
			BEGIN
				DECLARE @TmpIdUF INT;

				SELECT TOP 1 @TmpIdUF = IdUF
				FROM consorcio.UnidadFuncional
				WHERE IdConsorcio = @IdConsorcio;

				PRINT('Borrando UF: ' + CAST(@TmpIdUF AS VARCHAR));
				EXEC consorcio.sp_BorrarUnidadFuncional
					@IdUF = @TmpIdUF;

			END

			DELETE FROM consorcio.Consorcio
			WHERE IdConsorcio = @IdConsorcio;

			PRINT('Consorcio ' + CAST(@IdConsorcio AS VARCHAR) + ' borrado exitosamente.');

		END

		ELSE
		BEGIN
			PRINT('NO existe el Consorcio');
			RAISERROR('NO existe el Consorcio', 10, 1);

		END

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() = 10
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
	@Tipo CHAR(1),
	@NroExpensa INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM expensas.Expensa WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa)
		BEGIN
			DELETE FROM expensas.Prorrateo
			WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;

			DELETE FROM expensas.EstadoFinanciero
			WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;

			DELETE FROM gastos.GastoExtraordinario
			WHERE Tipo = @Tipo AND nroExpensa = @NroExpensa;

			WHILE EXISTS(SELECT 1 FROM gastos.GastoOrdinario WHERE nroExpensa = @NroExpensa AND Tipo = @Tipo)
			BEGIN
				DECLARE @TmpIdGO INT;

				SELECT TOP 1 @TmpIdGO = IdGO
				FROM gastos.GastoOrdinario
				WHERE nroExpensa = @NroExpensa AND Tipo = @Tipo;

				PRINT('Borrando Gasto Ordinario: ' + CAST(@TmpIdGO AS VARCHAR));

				EXEC gastos.sp_BorrarGastoOrdinario
					@IdGO = @TmpIdGO,
					@Tipo = @Tipo;

			END

			DELETE FROM expensas.Expensa
			WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;

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
--				  ORDINARIO				       --
--											   --
-------------------------------------------------

CREATE OR ALTER PROCEDURE gastos.sp_BorrarGastoOrdinario
	@IdGO INT,
	@Tipo CHAR(1)
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

		IF EXISTS(SELECT 1 FROM gastos.GastoOrdinario WHERE IdGO = @IdGO AND Tipo = @Tipo)
		BEGIN

			DELETE FROM gastos.Generales WHERE IdGO = @IdGO AND Tipo = @Tipo;
			DELETE FROM gastos.Seguros WHERE IdGO = @IdGO AND Tipo = @Tipo;
			DELETE FROM gastos.Honorarios WHERE IdGO = @IdGO AND Tipo = @Tipo;
			DELETE FROM gastos.Mantenimiento WHERE IdGO = @IdGO AND Tipo = @Tipo;


			WHILE EXISTS(SELECT 1 FROM gastos.Limpieza WHERE IdGO = @IdGO AND Tipo = @Tipo)
			BEGIN
				DECLARE @TmpLimpieza int;

				SELECT TOP 1 @TmpLimpieza = IdLimpieza
				FROM gastos.Limpieza
				WHERE IdGO = @IdGO AND Tipo = @Tipo;

				PRINT('Borrando Limpieza: ' + CAST(@TmpLimpieza AS VARCHAR));

				EXEC gastos.sp_BorrarLimpieza
					@IdLimpieza = @TmpLimpieza,
					@IdGO = @IdGO;

			END

			DELETE FROM gastos.GastoOrdinario
			WHERE IdGO = @IdGO AND Tipo = @Tipo;

		END

		ELSE
		BEGIN
			PRINT('No existe el Gasto Ordinario');
			RAISERROR('No existe el Gasto Ordinario', 10, 1);

		END

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		IF ERROR_SEVERITY() > 10
		BEGIN
			PRINT('Error en SP gastos.sp_BorrarGastoOrdinario: ' + ERROR_MESSAGE());
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			RAISERROR('ERROR en el borrado de Gasto Ordinario', 16, 1);

		END
		IF ERROR_SEVERITY() = 10
		BEGIN
			PRINT('Advertencia en SP gastos.sp_BorrarGastoOrdinario: ' + ERROR_MESSAGE());
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





