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
create or alter function hashArchivo(@rutaArch nvarchar(255))
returns varchar(64) as 
    begin
        declare @hash varchar(64);
        declare @nombArch nvarchar(255) = right(@rutaArch, charindex('\', reverse(@rutaArch)) - 1);
        set @hash = CONVERT(varchar(64), hashbytes('SHA2_256', @nombArch + cast(getdate() as varchar(30))), 2);
        return @hash;
    end
    go
