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
