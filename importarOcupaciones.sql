create or alter procedure consorcio.importarocupaciones
	@rutaarchpersonas nvarchar(255),
	@rutaarchuf nvarchar(255)
as
begin
	set nocount on;

	declare @sql nvarchar(max);

	begin try
		print 'iniciando importación de ocupaciones desde archivos csv...';

		-- cargar datos temporales
		if object_id('tempdb..#temppersonas') is not null drop table #temppersonas;
		if object_id('tempdb..#tempuf') is not null drop table #tempuf;

		create table #temppersonas (
			nombre nvarchar(50), apellido nvarchar(50), dni varchar(10),
			email nvarchar(100), telefono nvarchar(15), cvu_cbu char(22), inquilino int
		);

		create table #tempuf (
			cvu_cbu char(22), nombreconsorcio nvarchar(50), nrouf int,
			piso nvarchar(10), departamento nvarchar(10)
		);

		set @sql = n'bulk insert #temppersonas from ''' + @rutaarchpersonas + ''' with (firstrow = 2, fieldterminator = '';'', rowterminator = ''\n'', codepage = ''65001'')';
		exec sp_executesql @sql;

		set @sql = n'bulk insert #tempuf from ''' + @rutaarchuf + ''' with (firstrow = 2, fieldterminator = ''|'', rowterminator = ''\n'', codepage = ''65001'')';
		exec sp_executesql @sql;

	
		declare @registrosinsertados int = 0;
		declare @registrosfallidos int = 0;

		-- crear tabla temporal con los datos procesados
		if object_id('tempdb..#datosparaocupacion') is not null
			drop table #datosparaocupacion;

		select	
			dni = ltrim(rtrim(p.dni)),
			rol = case when p.inquilino = 1 then 'inquilino' else 'propietario' end,
			iduf = u.nrouf,
			row_number() over (order by p.dni) as rowid
		into #datosparaocupacion
		from #temppersonas p
		inner join #tempuf u on ltrim(rtrim(p.cvu_cbu)) = ltrim(rtrim(u.cvu_cbu))
		where not exists (
			select 1 from consorcio.ocupacion oc	
			where oc.dni = ltrim(rtrim(p.dni)) and oc.iduf = u.nrouf
		);

		-- procesar cada registro llamando al procedure
		declare @total int = (select count(*) from #datosparaocupacion);
		declare @contador int = 1;

		print 'registros a procesar: ' + cast(@total as varchar);

		while @contador <= @total
		begin
			declare @dni varchar(10), @rol char(11), @iduf int;

			select @dni = dni, @rol = rol, @iduf = iduf
			from #datosparaocupacion	
			where rowid = @contador;

			begin try
				exec consorcio.sp_agrocupacion	
					@rol = @rol,
					@iduf = @iduf,
					@dni = @dni;
				
				set @registrosinsertados = @registrosinsertados + 1;
				print 'ocupación insertada: dni ' + @dni + ' en uf ' + cast(@iduf as varchar) + ' como ' + @rol;
			end try
			begin catch
				set @registrosfallidos = @registrosfallidos + 1;
				print 'error al insertar ocupación para dni ' + @dni + ': ' + error_message();
			end catch

			set @contador = @contador + 1;
		end

		print 'importación de ocupaciones completada.';
		print 'ocupaciones insertadas: ' + cast(@registrosinsertados as varchar);
		print 'ocupaciones fallidas: ' + cast(@registrosfallidos as varchar);


		drop table #temppersonas;
		drop table #tempuf;
		drop table #datosparaocupacion;

	end try
	begin catch
		print 'error durante la importación: ' + error_message();
		if object_id('tempdb..#temppersonas') is not null drop table #temppersonas;
		if object_id('tempdb..#tempuf') is not null drop table #tempuf;
		if object_id('tempdb..#datosparaocupacion') is not null drop table #datosparaocupacion;
		throw;
	end catch
end
go

exec consorcio.importarocupaciones	
	@rutaarchpersonas = 'c:\archivos_para_el_tp\inquilino-propietarios-datos.csv',
	@rutaarchuf = 'c:\archivos_para_el_tp\inquilino-propietarios-uf.csv';

