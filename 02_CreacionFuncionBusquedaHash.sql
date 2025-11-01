create or alter function hashArchivo(@rutaArch nvarchar(255))
returns varchar(64) as 
    begin
        declare @hash varchar(64);
        declare @nombArch nvarchar(255) = right(@rutaArch, charindex('\', reverse(@rutaArch)) - 1);
        set @hash = CONVERT(varchar(64), hashbytes('SHA2_256', @nombArch + cast(getdate() as varchar(30))), 2);
        return @hash;
    end
    go
