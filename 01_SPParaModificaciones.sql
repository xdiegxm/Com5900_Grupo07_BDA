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
--			    MODIFICACIONES		           --
--											   --
-------------------------------------------------
USE master
USE Com5600G07
GO
------------------------------------------ SCHEMA EXPENSAS -------------------------------------------
---------------------------------------- Para Tabla Expensa ----------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifExpensa
    @NroExpensa INT,
    @IdConsorcio INT = NULL,
    @FechaGeneracion DATE = NULL,
    @FechaVto1 DATE = NULL,
    @FechaVto2 DATE = NULL,
    @MontoTotal DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM expensas.Expensa
            WHERE nroExpensa = @NroExpensa
        )
        BEGIN
            PRINT('No existe una expensa con el número proporcionado.');
            RETURN;
        END

        IF @IdConsorcio IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
            BEGIN
                PRINT('El IdConsorcio ingresado no existe.');
                RAISERROR('Error: IdConsorcio inexistente.', 16, 1);
            END
        END

        IF @MontoTotal IS NOT NULL AND @MontoTotal < 0
        BEGIN
            PRINT('El Monto Total no puede ser negativo.');
            RAISERROR('Error: Monto total negativo.', 16, 1);
        END

        DECLARE @FechaG DATE;
        SELECT @FechaG = ISNULL(@FechaGeneracion, FechaGeneracion) FROM expensas.Expensa WHERE nroExpensa = @NroExpensa;

        IF @FechaVto1 IS NOT NULL AND @FechaVto1 < @FechaG
        BEGIN
            PRINT('La fecha de Vencimiento 1 no puede ser anterior a la fecha de Generación.');
            RAISERROR('Error: Vencimiento 1 anterior a Generación.', 16, 1);
        END

        IF @FechaVto2 IS NOT NULL AND @FechaVto2 < @FechaG
        BEGIN
            PRINT('La fecha de Vencimiento 2 no puede ser anterior a la fecha de Generación.');
            RAISERROR('Error: Vencimiento 2 anterior a Generación.', 16, 1);
        END
        
        UPDATE expensas.Expensa
        SET 
            idConsorcio = ISNULL(@IdConsorcio, idConsorcio),
            fechaGeneracion = ISNULL(@FechaGeneracion, fechaGeneracion),
            fechaVto1 = ISNULL(@FechaVto1, fechaVto1),
            fechaVto2 = ISNULL(@FechaVto2, fechaVto2),
            montoTotal = ISNULL(@MontoTotal, montoTotal)
        WHERE 
            nroExpensa = @NroExpensa;

        PRINT('Expensa actualizada correctamente.');
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la expensa.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

---------------------------------------- Para Tabla Prorrateo ----------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifProrrateo
    @Tipo CHAR(1),
    @NroExpensa INT,
    @IdUF INT,
    @SaldoAnterior DECIMAL(12,2) = NULL,
    @PagosRecibidos DECIMAL(12,2) = NULL,
    @InteresMora DECIMAL(12,2) = NULL,
    @ExpensaOrdinaria DECIMAL(12,2) = NULL,
    @ExpensaExtraordinaria DECIMAL(12,2) = NULL,
    @Total DECIMAL(12,2) = NULL,
    @Deuda DECIMAL(12,2) = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        -- Validar existencia del prorrateo
        IF NOT EXISTS (
            SELECT 1 
            FROM expensas.Prorrateo
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF
        )
        BEGIN
            PRINT('No existe un prorrateo con el Tipo, NroExpensa e IdUF proporcionados.');
            RETURN;
        END

        -- Validar referencia a Expensa
        IF NOT EXISTS (
            SELECT 1 FROM expensas.Expensa WHERE NroExpensa = @NroExpensa
        )
        BEGIN
            PRINT('No existe la expensa asociada.');
            RAISERROR('.', 16, 1);
        END

        -- Validar referencia a Unidad Funcional
        IF NOT EXISTS (
            SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF
        )
        BEGIN
            PRINT('No existe la unidad funcional asociada.');
            RAISERROR('.', 16, 1);
        END

        ----------------------------
        -- Actualizaciones individuales
        ----------------------------

        -- SaldoAnterior
        IF @SaldoAnterior IS NOT NULL
        BEGIN
            IF @SaldoAnterior < 0
            BEGIN
                PRINT('El saldo anterior no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET SaldoAnterior = @SaldoAnterior
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- PagosRecibidos
        IF @PagosRecibidos IS NOT NULL
        BEGIN
            IF @PagosRecibidos < 0
            BEGIN
                PRINT('Los pagos recibidos no pueden ser negativos.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET PagosRecibidos = @PagosRecibidos
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- InteresMora
        IF @InteresMora IS NOT NULL
        BEGIN
            IF @InteresMora < 0
            BEGIN
                PRINT('El interés por mora no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET InteresMora = @InteresMora
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- ExpensaOrdinaria
        IF @ExpensaOrdinaria IS NOT NULL
        BEGIN
            IF @ExpensaOrdinaria < 0
            BEGIN
                PRINT('La expensa ordinaria no puede ser negativa.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET ExpensaOrdinaria = @ExpensaOrdinaria
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- ExpensaExtraordinaria
        IF @ExpensaExtraordinaria IS NOT NULL
        BEGIN
            IF @ExpensaExtraordinaria < 0
            BEGIN
                PRINT('La expensa extraordinaria no puede ser negativa.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET ExpensaExtraordinaria = @ExpensaExtraordinaria
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- Total
        IF @Total IS NOT NULL
        BEGIN
            IF @Total < 0
            BEGIN
                PRINT('El total no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET Total = @Total
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- Deuda
        IF @Deuda IS NOT NULL
        BEGIN
            IF @Deuda < 0
            BEGIN
                PRINT('La deuda no puede ser negativa.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET Deuda = @Deuda
            WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        PRINT('Prorrateo actualizado correctamente.');
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el prorrateo.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

------------------------------------------ SCHEMA PAGO -------------------------------------------
---------------------------------------- Para Tabla Pago ----------------------------------------
CREATE OR ALTER PROCEDURE Pago.sp_ModifPago
    @IdPago INT,
    @Fecha DATE = NULL,
    @Importe DECIMAL(12,2) = NULL,
    @CuentaOrigen CHAR(22) = NULL,
    @IdUF INT = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        ------------------------------------------------------------
        -- Validar existencia del pago
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Pago.Pago WHERE IdPago = @IdPago)
        BEGIN
            PRINT('No existe un pago con el IdPago proporcionado.');
            RETURN;
        END

        ------------------------------------------------------------
        -- Modificar Fecha
        ------------------------------------------------------------
        IF @Fecha IS NOT NULL
        BEGIN
            IF @Fecha > GETDATE()
            BEGIN
                PRINT('La fecha del pago no puede ser futura.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET Fecha = @Fecha
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar Importe
        ------------------------------------------------------------
        IF @Importe IS NOT NULL
        BEGIN
            IF @Importe < 0
            BEGIN
                PRINT('El importe no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET Importe = @Importe
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar CuentaOrigen
        ------------------------------------------------------------
        IF @CuentaOrigen IS NOT NULL AND @CuentaOrigen <> ''
        BEGIN
            SET @CuentaOrigen = TRIM(@CuentaOrigen);
            IF LEN(@CuentaOrigen) <> 22
            BEGIN
                PRINT('La cuenta origen debe tener exactamente 22 caracteres.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET CuentaOrigen = @CuentaOrigen
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar IdUF
        ------------------------------------------------------------
        IF @IdUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
            BEGIN
                PRINT('El IdUF proporcionado no existe en consorcio.UnidadFuncional.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET IdUF = @IdUF
            WHERE IdPago = @IdPago;
        END

        PRINT('Pago actualizado correctamente.');
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el pago.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

------------------------------------------ SCHEMA CONSORCIO -------------------------------------------
-------------------------------------------------
--											   --
--			       CONSORCIO		           --
--											   --
-------------------------------------------------

create or alter procedure consorcio.sp_ModifConsorcio
    @IdConsorcio int,
    @NombreConsorcio varchar(40) = NULL,
    @Direccion nvarchar(100) = NULL,
    @Superficie_Total decimal(10,2) = NULL,
    @MoraPrimerVTO decimal(5,2) = NULL,
    @MoraProxVTO decimal(5,2) = NULL
as
begin
    set nocount on;

 begin try
        if not exists (select 1 from consorcio.Consorcio where IdConsorcio = @IdConsorcio)
        begin
            print 'Error: No existe un Consorcio con el ID proporcionado para modificar';
        end
        else
        begin
            --COALESCE sirve para un valor por defecto a los nulos (creo que el archivo no tiene ninguno igual, pero por las dudas lo mando)
            update consorcio.Consorcio
            set 
                NombreConsorcio = COALESCE(@NombreConsorcio, NombreConsorcio),
                Direccion = COALESCE(@Direccion, Direccion),
                Superficie_Total = COALESCE(@Superficie_Total, Superficie_Total),
                MoraPrimerVTO = COALESCE(@MoraPrimerVTO, MoraPrimerVTO),
                MoraProxVTO = COALESCE(@MoraProxVTO, MoraProxVTO)
            where 
                IdConsorcio = @IdConsorcio;
                
            --agrego un msj de que se modifico bien
            if @@ROWCOUNT = 0 --Si el rowcount da 0, significa que no se modifico ningun registro
            begin
                print 'El Consorcio existe, pero no se actualizaron datos';
            end
            else
            begin
                print 'Consorcio con ID ' + cast(@IdConsorcio as varchar) + ' actualizado';
            end
        end
    end try
    begin catch
        print 'ERROR al modificar el Consorcio';
    end catch
end
go
-------------------------------------------------
--											   --
--			   UNIDAD FUNCIONAL		           --
--											   --
-------------------------------------------------
create or alter procedure consorcio.sp_ModifUnidadFuncional
    @IdUF int,
    @Piso nvarchar(10) = NULL,
    @Depto nvarchar(10) = NULL,
    @Superficie decimal(6,2) = NULL,
    @Coeficiente decimal(5,2) = NULL,
    @IdConsorcio int = NULL,
    @PersonaDNI varchar(10) = NULL -- Nombre del campo es 'persona'
as
begin
    set nocount on;

    begin try
        -- verifico que exista la pk
        if not exists (select 1 from consorcio.UnidadFuncional where IdUF = @IdUF)
        begin
            print 'Error: no existe una Unidad Funcional con ese idUF';
            return;
        end

        -- verifico que las fk tambien existan
        if @IdConsorcio is not null and not exists (select 1 from consorcio.Consorcio where IdConsorcio = @IdConsorcio)
        begin
            print 'Error: El IdConsorcio especificado no existe. No se puede actualizar la Unidad Funcional';
            return;
        end

        if @PersonaDNI is not null and not exists (select 1 from consorcio.Persona where DNI = @PersonaDNI)
        begin
            print 'Error: ese dni no existe. No se puede actualizar la Unidad Funcional';
            return;
        END

        -- COALESCE: Mantiene el valor anterior si el parámetro es NULL.
        UPDATE consorcio.UnidadFuncional
        set 
            Piso = COALESCE(@Piso, Piso),
            Depto = COALESCE(@Depto, Depto),
            Superficie = COALESCE(@Superficie, Superficie),
            Coeficiente = COALESCE(@Coeficiente, Coeficiente),
            IdConsorcio = COALESCE(@IdConsorcio, IdConsorcio),
            persona = COALESCE(@PersonaDNI, persona)
        where 
            IdUF = @IdUF;
            
        -- Mensaje de resultado
        if @@ROWCOUNT = 0 
        begin
            print 'La UF existe, pero no se actualizaron datos';
        end
        else
        begin
            print 'Unidad Funcional con IdUF ' + cast(@IdUF as varchar) + ' actualizada';
        end

    end try
    begin catch
        print ' ERROR no se pudo modificar consorcio.UnidadFuncional';
    end catch
end 
go

-------------------------------------------------
--											   --
--			       OCUPACION                   --
--											   --
-------------------------------------------------
create or alter procedure consorcio.sp_ModifOcupacion
    @Id_Ocupacion int,
    @Rol char(11) = NULL,
    @FechaInicio date = NULL,
    @FechaFin date = NULL,
    @IdUF int = NULL,
    @DNI varchar(10) = NULL
as
begin
    set nocount on

    begin try
        -- valido pk
        if not exists (select 1 from consorcio.Ocupacion where Id_Ocupacion = @Id_Ocupacion)
        begin
            print 'Error: No existe una Ocupación con el ID proporcionado para modificar';
            return;
        end

        -- valido fk 
        if @IdUF is not null and not exists (select 1 from consorcio.UnidadFuncional where IdUF = @IdUF)
        begin
            print 'Error: El IdUF especificado no existe';
            return;
        end
        if @DNI is not null and not exists (SELECT 1 FROM consorcio.Persona WHERE DNI = @DNI)
        begin
            print 'Error: El DNI de la Persona especificada no existe';
            return;
        end

        update consorcio.Ocupacion
        set 
            Rol = COALESCE(@Rol, Rol),
            FechaInicio = COALESCE(@FechaInicio, FechaInicio),
            FechaFin = COALESCE(@FechaFin, FechaFin),
            IdUF = COALESCE(@IdUF, IdUF),
            DNI = COALESCE(@DNI, DNI)
        where 
            Id_Ocupacion = @Id_Ocupacion;
            
        if @@ROWCOUNT = 0
        begin
            print 'La Ocupación existe, pero no se proporcionaron valores nuevos para actualizar';
        end
        else
        begin
            print 'Ocupación con ID ' + CAST(@Id_Ocupacion AS VARCHAR) + 'actualizada correctamente';
        end

    end try
    begin catch

            PRINT 'ERROR al modificar la Ocupación';
    end catch
end
go
-------------------------------------------------
--											   --
--			       BAULERA		               --
--											   --
-------------------------------------------------
create or alter procedure consorcio.sp_ModifBaulera
	@id_baulera int,
	@tamanio decimal(10,2) = NULL,
	@iduf int = NULL
as
begin
	set nocount on;

	begin try
		-- validar pk
		if not exists (select 1 from consorcio.baulera where id_baulera = @id_baulera)
		begin
			print 'error: no hay baulera con ese id';
			return;
		end

		-- validar fk 
		if @iduf is not null and not exists (select 1 from consorcio.unidadfuncional where iduf = @iduf)
		begin
			print 'error: no hay UF ocn ese id';
			return;
		end

		update consorcio.baulera
		set	
			tamanio = COALESCE(@tamanio, tamanio),
			iduf = COALESCE(@iduf, iduf)
		where	
			id_baulera = @id_baulera;
			
		if @@ROWCOUNT = 0
		begin
			print 'la baulera existe, pero no se proporcionaron valores nuevos para actualizar';
		end
		else
		begin
			print 'baulera con id ' + cast(@id_baulera as varchar) + ' actualizada';
		end

	end try
	begin catch
		print 'error al modificar la baulera';
	end catch
end
go
-------------------------------------------------
--											   --
--			       COCHERA		               --
--											   --
-------------------------------------------------
create or alter procedure consorcio.sp_ModifCochera
	@id_cochera int,
	@tamanio decimal(10,2) = NULL,
	@iduf int = NULL
as
begin
	set nocount on;

	begin try
		--valido pk
		if not exists (select 1 from consorcio.cochera where id_cochera = @id_cochera)
		begin
			print 'error: no existe una cochera con el id proporcionado para modificar.';
			return;
		end

		-- valido fk
		if @iduf is not null and not exists (select 1 from consorcio.unidadfuncional where iduf = @iduf)
		begin
			print 'error: el iduf especificado no existe.';
			return;
		end

		update consorcio.cochera
		set	
			tamanio = coalesce(@tamanio, tamanio),
			iduf = coalesce(@iduf, iduf)
		where	
			id_cochera = @id_cochera;
			
	
		if @@rowcount = 0
		begin
			print 'la cochera existe, pero no se proporcionaron valores nuevos para actualizar';
		end
		else
		begin
			print 'cochera con id ' + cast(@id_cochera as varchar) + ' actualizada correctamente.';
		end

	end try
	begin catch
		print 'error al modificar la cochera.';
	end catch
end
go

------------------------------------------ SCHEMA GASTOS -------------------------------------------
-------------------------------------------------
--											   --
--			TABLA GASTO EXTRAORDINARIO		   --
--											   --
-------------------------------------------------
create or alter procedure gastos.sp_modifgastoextraordinario
    @idge int,
    @nroexpensa int = NULL,
    @detalle nvarchar(100) = NULL,
    @importetotal decimal(12,2) = NULL,
    @cuotas bit = NULL,
    @importecuota decimal(12,2) = NULL,
    @cuotaactual tinyint = NULL,
    @totalcuotas tinyint = NULL
as
begin
    set nocount on;

    declare @tipo char(1) = 'E'; -- el tipo siempre es E
    
    begin try
        --valido pk
        if not exists (select 1 from gastos.Gasto_Extraordinario where idGasto = @idge)
        begin
            raiserror('Error: No existe un Gasto Extraordinario con el ID proporcionado.', 16, 1);
            return;
        end

        --valido fk
        if @nroexpensa is not null and not exists (select 1 from expensas.expensa where nroExpensa = @nroexpensa)
        begin
            raiserror('Error: El nroExpensa proporcionado no existe como Expensa Extraordinaria (Tipo E).', 16, 1);
            return;
        end

        update gastos.Gasto_Extraordinario
        set
            cuotaactual = coalesce(@cuotaactual, cuotaactual),
            totalcuotas = coalesce(@totalcuotas, totalcuotas)
        where
            idGasto = @idge;

        if @@rowcount > 0
        begin
            print 'Gasto Extraordinario con ID ' + cast(@idge as varchar) + ' actualizado correctamente';
        end
        else
        begin
            print 'Gasto Extraordinario existe, pero no se proporcionaron valores nuevos para actualizar';
        end

    end try
    begin catch
        print 'error no se pudo modificar la tabla de gastos extraordinarios'
    end catch
end
go
-------------------------------------------------
--											   --
--			  GASTOS ORDINARIOS		           --
--											   --
-------------------------------------------------
create or alter procedure gastos.sp_modifgastoordinario
    @idgo int,
    @descripcion varchar(50) = null,
    @importe decimal(12,2) = null,
    @nrofactura varchar(15) = null,
    @nroexpensa int = null
as
begin
    set nocount on;

    declare @tipo char(1) = 'O'; -- constante, el tipo siempre es 'O'

    begin try
        --valido pk
        if not exists (select 1 from gastos.Gasto_Ordinario where idGasto = @idgo)
        begin
            print'Error: No existe un Gasto Ordinario con el ID proporcionado'
            return;
        end

        --valido fk
        if @nroexpensa is not null and not exists (select 1 from expensas.expensa where nroexpensa = @nroexpensa)
        begin
            print 'Error: El nroExpensa proporcionado no existe como Expensa Ordinaria (Tipo O)'
            return;
        end


        update gastos.Gasto_Ordinario
        set
            descripcion = coalesce(@descripcion, descripcion),
            importe = coalesce(@importe, importe),
            nrofactura = coalesce(@nrofactura, nrofactura),
            nroexpensa = coalesce(@nroexpensa, nroexpensa)
        where
            idGasto = @idgo;
            

        if @@rowcount > 0
        begin
            print 'Gasto Ordinario con ID ' + cast(@idgo as varchar) + ' actualizado correctamente.';
        end
        else
        begin
            print 'Gasto Ordinario existe, pero no se proporcionaron valores nuevos para actualizar.';
        end

    end try
    begin catch
        print 'error no se pudo modificar la tabla de gastos ordinarios'
    end catch
end
go



