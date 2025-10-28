CREATE OR ALTER PROCEDURE consorcio.importarPersonas
@rutaArch nvarchar(255)
as
BEGIN 
    SET NOCOUNT ON;
    declare @hashArch varchar(64);
    declare @nameArch nvarchar(255);
    declare @archProcesado int = 0;
    
    begin try

       --busco el hash del archivo
       set @hashArch = dbo.hashArchivo(@rutaArch);
       set @nameArch = right(@rutaArch, charindex('\', reverse(@rutaArch)) - 1);
       
       print 'iniciando importacion del archivo: ' + @nameArch;



        --creo una temp para la estructura del csv
        if object_id ('tempdb..#personasTemp') is not null
            drop table #personasTemp;

        create table #personasTemp (
            nombre nvarchar(50),
            apellido nvarchar(50),
            dni varchar(10),
            email nvarchar(100),
            tel varchar(15),
            CVU_CBU char(22),
            inquilino int
        );

       -- importo el csv y uso ; como separador de campo
      
       declare @sql nvarchar(max);
       set @sql = N'bulk insert #personasTemp from '''+@rutaArch + '''with (
       firstrow = 2, 
       fieldterminator = '';'',
       rowterminator = ''\n'', 
       codepage = ''65001'',
       tablock)';
       
       exec sp_executesql @sql;
       
       insert into consorcio.Persona(DNI, Nombre ,Apellido, Email, Telefono, CVU, IdUF)
       select 
            LTRIM(RTRIM(dni)),
            LTRIM(RTRIM(nombre)),
            LTRIM(RTRIM(apellido)),
            LTRIM(RTRIM(email)),
            LTRIM(RTRIM(tel)),
            LTRIM(RTRIM(CVU_CBU)), 
            1 --esto lo tengo que cambiar, tengo que encontrar la forma de ver que cada 
                --uno tenga su uf
        from #personasTemp
        
        --me quedaba con espacios, por eso uso ltrim y rtrim

        print 'termino la importacion, cantidad de registros: ' + cast(@@rowcount as varchar);
        drop table #personasTemp;

    end try
    
    begin catch
    
        print 'error';
    
        if OBJECT_ID('tempdb..#personasTemp') is not null
            drop table #personasTemp;
        throw;
     
     end catch
end 


IF OBJECT_ID('ArchivosProcesados','U') IS NULL
BEGIN
    CREATE TABLE ArchivosProcesados (
        IdArchivo INT IDENTITY(1,1) PRIMARY KEY,
        NombreArchivo NVARCHAR(255) NOT NULL,
        HashArchivo VARCHAR(64) NOT NULL,
        FechaProcesado DATETIME2 DEFAULT GETDATE(),
        TipoArchivo VARCHAR(50) NOT NULL,
        RegistrosProcesados INT DEFAULT 0,
        Usuario VARCHAR(50) DEFAULT SYSTEM_USER
    );
    
    PRINT 'Tabla ArchivosProcesados creada.';
END
GO


execute consorcio.importarPersonas @rutaArch = 'C:\Archivos_para_el_TP\inquilino-propietarios-datos.csv'

select * from consorcio.Persona
