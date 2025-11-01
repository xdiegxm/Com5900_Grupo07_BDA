CREATE OR ALTER PROCEDURE consorcio.importarDatosCompleto
    @rutaArchPersonas NVARCHAR(255),
    @rutaArchUF NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        PRINT 'Iniciando importación desde archivos CSV...';

   
        IF OBJECT_ID('tempdb..#tempPersonas') IS NOT NULL
            DROP TABLE #tempPersonas;

        CREATE TABLE #tempPersonas (
            Nombre NVARCHAR(50),
            Apellido NVARCHAR(50),
            DNI VARCHAR(10),
            Email NVARCHAR(100),
            Telefono NVARCHAR(15),
            CVU_CBU CHAR(22),
            Inquilino INT
        );

        SET @sql = N'BULK INSERT #tempPersonas FROM ''' + @rutaArchPersonas + ''' 
        WITH (FIRSTROW = 2, FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        PRINT 'Datos de personas cargados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL
            DROP TABLE #tempUF;

        CREATE TABLE #tempUF (
            CVU_CBU CHAR(22),
            NombreConsorcio NVARCHAR(50),
            NroUF INT,
            Piso NVARCHAR(10),
            Departamento NVARCHAR(10)
        );

        SET @sql = N'BULK INSERT #tempUF FROM ''' + @rutaArchUF + ''' 
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ''|'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'')';
        EXEC sp_executesql @sql;

        PRINT 'Datos de UF cargados: ' + CAST(@@ROWCOUNT AS VARCHAR);

        PRINT 'Eliminando duplicados...';
        
        IF OBJECT_ID('tempdb..#personasSinDuplicados') IS NOT NULL
            DROP TABLE #personasSinDuplicados;

        SELECT 
            DNI = LTRIM(RTRIM(DNI)),
            Nombre = LEFT(LTRIM(RTRIM(Nombre)), 30),
            Apellido = LEFT(LTRIM(RTRIM(Apellido)), 30),
            Email = CASE WHEN LTRIM(RTRIM(Email)) = '' THEN NULL ELSE LEFT(LTRIM(RTRIM(Email)), 40) END,
            Telefono = CASE WHEN LTRIM(RTRIM(Telefono)) = '' THEN NULL ELSE LEFT(LTRIM(RTRIM(Telefono)), 15) END,
            CVU_CBU = LTRIM(RTRIM(CVU_CBU)),
            Inquilino = Inquilino,
            ROW_NUMBER() OVER (PARTITION BY LTRIM(RTRIM(DNI)) ORDER BY (SELECT NULL)) as RowNum
        INTO #personasSinDuplicados
        FROM #tempPersonas;

        DELETE FROM #personasSinDuplicados WHERE RowNum > 1;

        PRINT 'Duplicados eliminados del archivo: ' + CAST(@@ROWCOUNT AS VARCHAR);


        PRINT 'Insertando datos en tabla Persona...';
        
        INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, idUF)
        SELECT 
            p.DNI,
            p.Nombre,
            p.Apellido,
            p.Email,
            p.Telefono,
            p.CVU_CBU,
            u.NroUF
        FROM #personasSinDuplicados p
        INNER JOIN #tempUF u ON p.CVU_CBU = LTRIM(RTRIM(u.CVU_CBU))
        WHERE NOT EXISTS (SELECT 1 FROM consorcio.Persona WHERE DNI = p.DNI);

        PRINT 'Personas insertadas: ' + CAST(@@ROWCOUNT AS VARCHAR);

        DROP TABLE #tempPersonas;
        DROP TABLE #tempUF;
        DROP TABLE #personasSinDuplicados;

        PRINT 'Importación completada exitosamente.';

    END TRY
    BEGIN CATCH
        PRINT 'Error durante la importación: ' + ERROR_MESSAGE();
        IF OBJECT_ID('tempdb..#tempPersonas') IS NOT NULL DROP TABLE #tempPersonas;
        IF OBJECT_ID('tempdb..#tempUF') IS NOT NULL DROP TABLE #tempUF;
        IF OBJECT_ID('tempdb..#personasSinDuplicados') IS NOT NULL DROP TABLE #personasSinDuplicados;
        THROW;
    END CATCH
END
GO