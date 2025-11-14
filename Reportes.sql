/*REPORTES*/
CREATE OR ALTER PROCEDURE report.sp_ReporteTopMorosos
    @IdConsorcio INT,
    @FormatoXML BIT = 0, -- 0 = Output normal, 1 = Formato XML
    @XmlSalida XML = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos Consorcio
    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El Consorcio no existe';
        RETURN;
    END

    -- Creamos una tabla temporal para guardar el ranking
    CREATE TABLE #RankingMorosos (
        DNI VARCHAR(10),
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        Email NVARCHAR(100),
        Telefono NVARCHAR(30),
        UnidadFuncional NVARCHAR(25),
        DeudaTotal DECIMAL(12,2),
        CantidadExpensasAdeudadas INT
    );

    -- Calcular e insertar los TOP 3 morosos
    INSERT INTO #RankingMorosos (DNI, Nombre, Apellido, Email, Telefono, UnidadFuncional, DeudaTotal, CantidadExpensasAdeudadas)
    SELECT TOP 3
        p.DNI,
        p.Nombre,
        p.Apellido,
        
        -- ------ INICIO DE LA CORRECCIÓN ------
        -- Usamos MAX() como un "agregado falso"
        -- Como DNI/Nombre/Apellido están en el GROUP BY, solo hay un Email/Telefono por grupo.
        -- MAX() simplemente seleccionará ese único valor desencriptado.
        ISNULL(MAX(seguridad.DecryptData(p.Email)), 'No informado'),
        ISNULL(MAX(seguridad.DecryptData(p.Telefono)), 'No informado'),
        -- ------ FIN DE LA CORRECCIÓN ------
        
        uf.Piso + ' - ' + uf.Depto,
        SUM(pr.Deuda),
        COUNT(pr.IdProrrateo)
    FROM 
        consorcio.Persona p
    INNER JOIN 
        consorcio.UnidadFuncional uf ON p.idUF = uf.IdUF
    INNER JOIN 
        expensas.Prorrateo pr ON uf.IdUF = pr.IdUF
    WHERE 
        uf.IdConsorcio = @IdConsorcio
        AND pr.Deuda > 0 -- Solo sumamos si hay deuda real
    GROUP BY 
        -- Agrupamos por la persona y la unidad
        p.DNI, p.Nombre, p.Apellido, 
        uf.Piso, uf.Depto
    ORDER BY 
        SUM(pr.Deuda) DESC;

    IF NOT EXISTS (SELECT 1 FROM #RankingMorosos)
    BEGIN
        PRINT 'XML: No se encontraron morosos con deuda pendiente para este consorcio.';
        -- Devolvemos una fila vacía
        IF @FormatoXML = 0 SELECT * FROM #RankingMorosos; 
        RETURN;
    END

    -- Salida XML
    IF @FormatoXML = 1
    BEGIN
        -- Generamos el XML en una variable interna
        DECLARE @ResultadoXML XML;
        
        SET @ResultadoXML = (
            SELECT 
                DNI AS "@DNI",
                Nombre, Apellido, Email, Telefono, UnidadFuncional,
                CAST(DeudaTotal AS DECIMAL(12,2)) AS DeudaTotal,
                CantidadExpensasAdeudadas
            FROM #RankingMorosos
            FOR XML PATH('Moroso'), ROOT('Top3Morosos'), TYPE
        );

        -- A. Si nos pidieron el dato por OUTPUT (desde otro SP), lo asignamos
        IF @XmlSalida IS NULL 
            -- Si es NULL, asumimos que no se pasó variable, así que mostramos por pantalla (SSMS)
            SELECT @ResultadoXML AS ReporteXML;
        ELSE
            -- Si NO es NULL (nos pasaron una variable), guardamos el dato ahí y NO hacemos SELECT
            SET @XmlSalida = @ResultadoXML;
    END
    ELSE
    BEGIN
        SELECT * FROM #RankingMorosos;
    END

    DROP TABLE #RankingMorosos;
END

EXEC report.sp_ReporteTopMorosos @IdConsorcio = 4, @FormatoXML = 0;