create or alter procedure consorcio.importarunidadesfuncionales
    @rutaarch nvarchar(255)
as
begin 
    set nocount on;
    
    declare @hash varchar(64);
    declare @nombrearchivo nvarchar(255);
    
    begin try
        -- obtener nombre del archivo
        set @nombrearchivo = right(@rutaarch, charindex('\', reverse(@rutaarch)) - 1);

        print '=== iniciando importación de unidades funcionales ===';
        print 'archivo: ' + @nombrearchivo;
        
        -- 1. crear tabla temporal
        if object_id('tempdb..#ufstemp') is not null
            drop table #ufstemp;

        create table #ufstemp (
            [nombre del consorcio] nvarchar(100),
            nrounidadfuncional nvarchar(10),
            piso nvarchar(10),
            departamento nvarchar(10),
            coeficiente nvarchar(10),  
            m2_unidad_funcional nvarchar(10),
            bauleras nvarchar(10),
            cochera nvarchar(10),
            m2_baulera nvarchar(10),
            m2_cochera nvarchar(10)
        );

        -- 2. importar archivo
        print 'importando archivo...';
        declare @sql nvarchar(max);
        
        set @sql = N'bulk insert #ufstemp from ''' + @rutaarch + ''' with (
            firstrow = 2,  
            fieldterminator = ''\t'',
            rowterminator = ''\n'',
            codepage = ''65001'',
            maxerrors = 1000
        )';
        
        exec sp_executesql @sql;
        
        declare @registrosleidos int = @@rowcount;
        print 'registros leídos del archivo: ' + cast(@registrosleidos as varchar);
        
        -- 3. limpiar datos vacíos
        delete from #ufstemp
        where ltrim(rtrim(isnull([nombre del consorcio], ''))) = '';

        -- 4. crear tabla temporal para consorcios nuevos
        if object_id('tempdb..#consorciosnuevos') is not null
            drop table #consorciosnuevos;

        create table #consorciosnuevos (
            nombreconsorcio nvarchar(100)
        );

        -- insertar consorcios que no existen
        insert into #consorciosnuevos (nombreconsorcio)
        select distinct ltrim(rtrim(t.[nombre del consorcio]))
        from #ufstemp t
        where not exists (
            select 1 
            from consorcio.consorcio c 
            where c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        );

        -- 5. insertar nuevos consorcios
        insert into consorcio.consorcio (nombreconsorcio, direccion, superficie_total, moraprimervto, moraproxvto)
        select 
            nombreconsorcio,
            'direccion ' + nombreconsorcio,
            1000.00,
            2.00,
            5.00
        from #consorciosnuevos;


        drop table #consorciosnuevos;

        -- 6. insertar unidades funcionales
        insert into consorcio.unidadfuncional (piso, depto, superficie, coeficiente, idconsorcio)
        select 
            ltrim(rtrim(t.piso)),
            ltrim(rtrim(t.departamento)),
            case 
                when isnumeric(t.m2_unidad_funcional) = 1 
                then cast(t.m2_unidad_funcional as decimal(6,2))
                else 0 
            end as superficie,
            case 
                when isnumeric(replace(t.coeficiente, ',', '.')) = 1 
                then cast(replace(t.coeficiente, ',', '.') as decimal(5,2))
                else 0 
            end as coeficiente,
            c.idconsorcio
        from #ufstemp t
        inner join consorcio.consorcio c 
            on c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        where ltrim(rtrim(isnull(t.piso, ''))) != ''
          and ltrim(rtrim(isnull(t.departamento, ''))) != '';

        declare @totalufs int = @@rowcount;
        
        -- 7. insertar bauleras
        insert into consorcio.baulera (tamanio, iduf)
        select 
            case 
                when isnumeric(t.m2_baulera) = 1 
                then cast(t.m2_baulera as decimal(10,2))
                else 0 
            end as tamanio,
            uf.iduf
        from #ufstemp t
        inner join consorcio.consorcio c 
            on c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        inner join consorcio.unidadfuncional uf 
            on uf.piso = ltrim(rtrim(t.piso)) 
            and uf.depto = ltrim(rtrim(t.departamento))
            and uf.idconsorcio = c.idconsorcio
        where ltrim(rtrim(isnull(t.bauleras, ''))) = 'si'
          and isnumeric(t.m2_baulera) = 1
          and cast(t.m2_baulera as decimal(10,2)) > 0;

        declare @totalbauleras int = @@rowcount;

        -- 8. insertar cocheras
        insert into consorcio.cochera (tamanio, iduf)
        select 
            case 
                when isnumeric(t.m2_cochera) = 1 
                then cast(t.m2_cochera as decimal(10,2))
                else 0 
            end as tamanio,
            uf.iduf
        from #ufstemp t
        inner join consorcio.consorcio c 
            on c.nombreconsorcio = ltrim(rtrim(t.[nombre del consorcio]))
        inner join consorcio.unidadfuncional uf 
            on uf.piso = ltrim(rtrim(t.piso)) 
            and uf.depto = ltrim(rtrim(t.departamento))
            and uf.idconsorcio = c.idconsorcio
        where ltrim(rtrim(isnull(t.cochera, ''))) = 'si'
          and isnumeric(t.m2_cochera) = 1
          and cast(t.m2_cochera as decimal(10,2)) > 0;

        declare @totalcocheras int = @@rowcount;

        -- 9. solo mensajes de resumen, sin select
        print 'resultados:';
        print 'total uf: ' + cast(@totalufs as varchar);
        print 'total bauleras: ' + cast(@totalbauleras as varchar);
        print 'total cocheras: ' + cast(@totalcocheras as varchar);
        
        drop table #ufstemp;
        
        print ' importación completada';

    end try
    begin catch
        print 'error: ' + error_message();
        print 'linea: ' + cast(error_line() as varchar);
        if object_id('tempdb..#ufstemp') is not null
            drop table #ufstemp;
        if object_id('tempdb..#consorciosnuevos') is not null
            drop table #consorciosnuevos;
        throw;
    end catch
end
go

exec consorcio.importarunidadesfuncionales @rutaarch = 'c:\archivos_para_el_tp\uf por consorcio.txt'

select * from consorcio.unidadfuncional