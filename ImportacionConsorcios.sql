sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

EXEC master.dbo.sp_MSset_oledb_prop 
    N'Microsoft.ACE.OLEDB.16.0', 
    N'AllowInProcess', 1;
    
EXEC master.dbo.sp_MSset_oledb_prop 
    N'Microsoft.ACE.OLEDB.16.0', 
    N'DynamicParameters', 1;

GO



CREATE OR ALTER PROCEDURE ImportarConsorciosDesdeExcel
    @RutaArchivo NVARCHAR(500),
    @NombreHoja NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Iniciando importación...';

    -- Crear tabla temporal
    CREATE TABLE #TempConsorcios (
        Consorcio VARCHAR(50),
        NombreConsorcio VARCHAR(100),
        Direccion VARCHAR(200),
        CantUnidades INT,
        SuperficieTotal DECIMAL(10,2)
    );

    -- Leer datos del Excel a temporal
    DECLARE @SQL NVARCHAR(MAX);

    -- Construir consulta dinámica
    SET @SQL = N'
    INSERT INTO #TempConsorcios 
    SELECT 
        [Consorcio],
        [Nombre del consorcio],
        [Domicilio],
        [Cant unidades funcionales],
        [m2 totales]
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.16.0'', 
        ''Excel 12.0;HDR=YES;Database=' + @RutaArchivo + ''', 
        ''SELECT * FROM [' + @NombreHoja + '$]''
    )';

    -- Ejecutar la consulta dinámica
    EXEC sp_executesql @SQL;


    -- Mostrar lo que se leyó
    PRINT 'Registros leídos del Excel: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
    
    SELECT * FROM #TempConsorcios;

    -- Insertar en tabla definitiva (CORREGIDO)
    INSERT INTO consorcio.Consorcio 
        (NombreConsorcio, Direccion, CantUnidadesFunc, Superficie_Total, MoraPrimerVTO, MoraProxVTO)
    SELECT 
        t.NombreConsorcio,
        t.Direccion,
        t.CantUnidades,
        t.SuperficieTotal,
        2,  -- MoraPrimerVTO
        5   -- MoraProxVTO
    FROM  #TempConsorcios t where not exists(select 1 from consorcio.Consorcio c where c.Direccion=t.Direccion and c.NombreConsorcio=t.NombreConsorcio);

    PRINT 'Importación completada. Registros insertados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

    -- Limpiar
    DROP TABLE #TempConsorcios;
END;
GO


/*Probar*/

EXEC ImportarConsorciosDesdeExcel 
    @RutaArchivo = N'C:\import SQL\datos varios.xlsx',
    @NombreHoja = N'Consorcios';

select * from consorcio.Consorcio
