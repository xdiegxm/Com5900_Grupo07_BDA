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

    -- Crear tabla temporal con identity para iterar
    CREATE TABLE #TempConsorcios (
        ID INT IDENTITY(1,1),
        Consorcio VARCHAR(50),
        NombreConsorcio VARCHAR(100),
        Direccion NVARCHAR(200),
        CantUnidades INT,
        SuperficieTotal DECIMAL(10,2)
    );

    -- Leer datos del Excel a temporal
    DECLARE @SQL NVARCHAR(MAX);

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

    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT 'Registros leídos del Excel: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'Error al leer el archivo Excel: ' + ERROR_MESSAGE();
        RETURN;
    END CATCH

    -- Mostrar lo que se leyó
    SELECT * FROM #TempConsorcios;

    -- Variables para el bucle
    DECLARE @ID INT = 1;
    DECLARE @MaxID INT;
    DECLARE @NombreConsorcio VARCHAR(100);
    DECLARE @Direccion NVARCHAR(200);
    DECLARE @CantUnidades INT;
    DECLARE @SuperficieTotal DECIMAL(10,2);
    DECLARE @Contador INT = 0;

    -- Obtener el máximo ID
    SELECT @MaxID = MAX(ID) FROM #TempConsorcios;

    -- Bucle WHILE para procesar cada registro
    WHILE @ID <= @MaxID
    BEGIN
        -- Obtener datos del registro actual
        SELECT 
            @NombreConsorcio = NombreConsorcio,
            @Direccion = Direccion,
            @CantUnidades = CantUnidades,
            @SuperficieTotal = SuperficieTotal
        FROM #TempConsorcios 
        WHERE ID = @ID;

        -- Verificar si el consorcio ya existe y procesar si no existe
        IF NOT EXISTS (
            SELECT 1 
            FROM consorcio.Consorcio c 
            WHERE c.Direccion = @Direccion 
              AND c.NombreConsorcio = @NombreConsorcio
        )
        BEGIN
            BEGIN TRY
                -- Ejecutar el stored procedure
                EXEC consorcio.sp_agrConsorcio 
                    @NombreConsorcio,
                    @Direccion,
                    @CantUnidades,
                    @SuperficieTotal,
                    2.00,  -- MoraPrimerVTO
                    5.00;  -- MoraProxVTO

                SET @Contador = @Contador + 1;
                PRINT 'Consorcio procesado: ' + @NombreConsorcio;
            END TRY
            BEGIN CATCH
                PRINT 'Error al procesar consorcio ' + ISNULL(@NombreConsorcio, 'N/A') + ': ' + ERROR_MESSAGE();
            END CATCH
        END
        ELSE
        BEGIN
            PRINT 'Consorcio ya existe, omitiendo: ' + @NombreConsorcio;
        END

        SET @ID = @ID + 1;
    END;

    PRINT 'Importación completada. Registros procesados: ' + CAST(@Contador AS VARCHAR(10));

    -- Limpiar
    DROP TABLE #TempConsorcios;
END;
GO

/*Probar*/

EXEC ImportarConsorciosDesdeExcel 
    @RutaArchivo = N'C:\import SQL\datos varios.xlsx',
    @NombreHoja = N'Consorcios';

select * from consorcio.Consorcio;

truncate table consorcio.Consorcio;