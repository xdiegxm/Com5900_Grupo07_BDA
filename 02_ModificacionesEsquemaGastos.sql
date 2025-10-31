-- sps esquema gastos

-- sp gastos extraordinarios
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
        if not exists (select 1 from gastos.gastoextraordinario where idge = @idge and tipo = @tipo)
        begin
            raiserror('Error: No existe un Gasto Extraordinario con el ID proporcionado.', 16, 1);
            return;
        end

        --valido fk
        if @nroexpensa is not null and not exists (select 1 from expensas.expensa where tipo = @tipo and nroexpensa = @nroexpensa)
        begin
            raiserror('Error: El nroExpensa proporcionado no existe como Expensa Extraordinaria (Tipo E).', 16, 1);
            return;
        end

        update gastos.gastoextraordinario
        set
            nroexpensa = coalesce(@nroexpensa, nroexpensa),
            detalle = coalesce(@detalle, detalle),
            importetotal = coalesce(@importetotal, importetotal),
            cuotas = coalesce(@cuotas, cuotas),
            importecuota = coalesce(@importecuota, importecuota),
            cuotaactual = coalesce(@cuotaactual, cuotaactual),
            totalcuotas = coalesce(@totalcuotas, totalcuotas)
        where
            idge = @idge and tipo = @tipo;

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

--sp gastos ordinarios
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
        if not exists (select 1 from gastos.gastoordinario where idgo = @idgo and tipo = @tipo)
        begin
            print'Error: No existe un Gasto Ordinario con el ID proporcionado'
            return;
        end

        --valido fk
        if @nroexpensa is not null and not exists (select 1 from expensas.expensa where tipo = @tipo and nroexpensa = @nroexpensa)
        begin
            print 'Error: El nroExpensa proporcionado no existe como Expensa Ordinaria (Tipo O)'
            return;
        end


        update gastos.gastoordinario
        set
            descripcion = coalesce(@descripcion, descripcion),
            importe = coalesce(@importe, importe),
            nrofactura = coalesce(@nrofactura, nrofactura),
            nroexpensa = coalesce(@nroexpensa, nroexpensa)
        where
            idgo = @idgo and tipo = @tipo;
            

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


--sps de la jerarquia de gastos ordinarios

-- sp gastos generales
create or alter procedure gastos.sp_modifgenerales
    @nrofactura varchar(15),
    @idgo int,
    @tipogasto varchar(20) = null,
    @nombreempresa varchar(30) = null,
    @importe decimal(12,2) = null
as
begin
    set nocount on;

    declare @tipo char(1) = 'O'; 

    begin try
        --valido pk
        if not exists (select 1 from gastos.generales where nrofactura = @nrofactura and idgo = @idgo)
        begin
            print'Error: No existe un registro de Gasto General con la Factura y IdGO proporcionados.'
            return;
        end

        update gastos.generales
        set
            tipogasto = coalesce(@tipogasto, tipogasto),
            nombreempresa = coalesce(@nombreempresa, nombreempresa),
            importe = coalesce(@importe, importe)
        where
            nrofactura = @nrofactura and idgo = @idgo;


        if @@rowcount > 0
        begin
            print 'Gasto General (' + @nrofactura + ') actualizado correctamente.';
        end

    end try
    begin catch
        print 'error no se pudo modificar la tabla de gastos generales'
    end catch
end
go

-- sp gastos seguros

create or alter procedure gastos.sp_modifseguros
    @nrofactura varchar(15),
    @idgo int,
    @nombreempresa varchar(30) = null,
    @importe decimal(12,2) = null
as
begin
    set nocount on;

    declare @tipo char(1) = 'O'; 

    begin try
        -- valido pk, que existe el seguro 
        if not exists (select 1 from gastos.seguros where nrofactura = @nrofactura and idgo = @idgo)
        begin
            print 'Error: No existe un registro de Seguro con la Factura y IdGO proporcionados.'
            return;
        end

        
        update gastos.seguros
        set
            nombreempresa = coalesce(@nombreempresa, nombreempresa),
            importe = coalesce(@importe, importe)
        where
            nrofactura = @nrofactura and idgo = @idgo;

   
        if @@rowcount > 0
        begin
            print 'Gasto de Seguros (' + @nrofactura + ') actualizado .';
        end

    end try
    begin catch
        print 'error: no se pudo modificar la tabla de seguros'
    end catch
end
go

-- sp gastos honorarios

create or alter procedure gastos.sp_modifhonorarios
    @nrofactura varchar(15),
    @idgo int,
    @importe decimal(12,2) = null
as
begin
    set nocount on;

    declare @tipo char(1) = 'O'; 

    begin try
        -- valido pk
        if not exists (select 1 from gastos.honorarios where nrofactura = @nrofactura and idgo = @idgo)
        begin
            print 'Error: No existe un registro de Honorarios con la Factura y IdGO proporcionados.'
            return;
        end

        update gastos.honorarios
        set
            importe = coalesce(@importe, importe)
        where
            nrofactura = @nrofactura and idgo = @idgo;

        if @@rowcount > 0
        begin
            print 'Gasto de Honorarios (' + @nrofactura + ') actualizado';
        end

    end try
    begin catch
        print 'error: no se actualizo la tabla de honorarios'
    end catch
end
go

-- sp gastos limpieza 


create or alter procedure gastos.sp_modiflimpieza
    @idlimpieza int,
    @idgo int,
    @importe decimal(12,2) = null
as
begin
    set nocount on;

    declare @tipo char(1) = 'O'; 

    begin try
        -- 1. validar existencia del gasto de limpieza (pk compuesta)
        if not exists (select 1 from gastos.limpieza where idlimpieza = @idlimpieza and idgo = @idgo)
        begin
            print 'Error: No existe un registro de Limpieza con el IdLimpieza y IdGO proporcionados.'
            return;
        end

        update gastos.limpieza
        set
            importe = coalesce(@importe, importe)
        where
            idlimpieza = @idlimpieza and idgo = @idgo;

        if @@rowcount > 0
        begin
            print 'Gasto de Limpieza (Id: ' + cast(@idlimpieza as varchar) + ') actualizado correctamente.';
        end

    end try
    begin catch
        print 'error: no se pudo modificar la tabla de limpieza'
    end catch
end
go

-- sp gastos mantenimiento 

create or alter procedure gastos.sp_modifmantenimiento
    @idmantenimiento int,
    @idgo int,
    @importe decimal(12,2) = null,
    @cuentabancaria char(22) = null
as
begin
    set nocount on;

    declare @tipo char(1) = 'O'; 

    begin try
        --valido pk
        if not exists (select 1 from gastos.mantenimiento where idmantenimiento = @idmantenimiento and idgo = @idgo)
        begin
            print'Error: No existe un registro de Mantenimiento con el IdMantenimiento y IdGO proporcionados.'
            return;
        end

        update gastos.mantenimiento
        set
            importe = coalesce(@importe, importe),
            cuentabancaria = coalesce(@cuentabancaria, cuentabancaria)
        where
            idmantenimiento = @idmantenimiento and idgo = @idgo;


        if @@rowcount > 0
        begin
            print 'gasto de Mantenimiento (Id: ' + cast(@idmantenimiento as varchar) + ') actualizado correctamente.';
        end

    end try
    begin catch
        print 'error: no se pudo modificar la tabla de mantenimiento'
    end catch
end
go