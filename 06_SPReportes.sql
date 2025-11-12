-------------------------------------------------
--											   --
--			BASES DE DATOS APLICADA		       --
--											   --
-------------------------------------------------
-- GRUPO: 07                                   --
-- INTEGRANTES:								   --
-- Mendoza, Diego Emanuel			           --
-- Vazquez, Isaac Benjamin                     --
-- Pizarro Dorgan, Fabricio Alejandro          --
-- Piñero, Agustín                             --
-- Comerci Salcedo, Francisco Ivan             --
-------------------------------------------------
-------------------------------------------------
--											   --
--		  STORED PROCEDURES REPORTES           --
--											   --
-------------------------------------------------

USE Com5600G07
GO

-------------------------------------------------
--											   --
--		       FLUJO CAJA SEMANAL              --
--											   --
-------------------------------------------------


CREATE OR ALTER PROCEDURE report.sp_ReporteFlujoCajaSemanal
    @FechaInicio DATE,
    @FechaFin DATE,
    @IdConsorcio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Vinculamos Pagos con Prorrateos para separar Ordinario/Extra
    WITH PagosConProrrateo AS (
        SELECT 
            p.Fecha,
            p.Importe,
            e.idConsorcio,
            ISNULL(pr.ExpensaOrdinaria, 0) AS MontoOrd,
            ISNULL(pr.ExpensaExtraordinaria, 0) AS MontoExt,
            (ISNULL(pr.ExpensaOrdinaria, 0) + ISNULL(pr.ExpensaExtraordinaria, 0)) AS TotalExp
        FROM 
            Pago.Pago p
        INNER JOIN 
            expensas.Prorrateo pr ON p.NroExpensa = pr.NroExpensa AND p.IdUF = pr.IdUF
        INNER JOIN 
            expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
        WHERE 
            p.Fecha >= @FechaInicio AND p.Fecha <= @FechaFin
            AND (@IdConsorcio IS NULL OR e.idConsorcio = @IdConsorcio)
    ),

    -- Calculamos la proporcion del pago real
    PagosCalculados AS (
        SELECT
            Fecha,
            -- Si el total prorrateado es 0, asumimos todo como Ordinario para evitar division por 0
            CASE WHEN TotalExp = 0 THEN Importe 
                 ELSE Importe * (MontoOrd / TotalExp) END AS PagoOrdinario,
            CASE WHEN TotalExp = 0 THEN 0 
                 ELSE Importe * (MontoExt / TotalExp) END AS PagoExtraordinario
        FROM PagosConProrrateo
    ),

    -- Agrupamos por Semana
    DatosSemanales AS (
        SELECT
            YEAR(Fecha) AS Anio,
            DATEPART(week, Fecha) AS Semana,
            SUM(PagoOrdinario) AS RecaudacionOrdinaria,
            SUM(PagoExtraordinario) AS RecaudacionExtraordinaria,
            SUM(PagoOrdinario + PagoExtraordinario) AS TotalSemana
        FROM PagosCalculados
        GROUP BY YEAR(Fecha), DATEPART(week, Fecha)
    )

    -- Salida Final
    SELECT 
        Anio,
        Semana,
        CAST(RecaudacionOrdinaria AS DECIMAL(12,2)) AS RecaudacionOrdinaria,
        CAST(RecaudacionExtraordinaria AS DECIMAL(12,2)) AS RecaudacionExtraordinaria,
        CAST(TotalSemana AS DECIMAL(12,2)) AS TotalSemana,
        
        -- Acumulado progresivo
        CAST(SUM(TotalSemana) OVER (ORDER BY Anio, Semana ROWS UNBOUNDED PRECEDING) AS DECIMAL(12,2)) AS AcumuladoProgresivo,
        
        -- Promedio del periodo
        --CAST(AVG(TotalSemana) OVER () AS DECIMAL(12,2)) AS PromedioPeriodo (PromedioPeriodo general)
        CAST(AVG(TotalSemana) OVER (ORDER BY Anio, Semana ROWS UNBOUNDED PRECEDING) AS DECIMAL(12,2)) AS PromedioPeriodo --(PromedioPeriodo por semana)
    FROM DatosSemanales
    ORDER BY Anio, Semana;
END
GO

--PARA PROBARLO
EXEC report.sp_ReporteFlujoCajaSemanal
    @FechaInicio = '2025-01-01', 
    @FechaFin = '2025-12-31', 
    @IdConsorcio = 6; -- Poner num de consorcio para realizar el reporte


-------------------------------------------------
--											   --
--		       RECAUDACION MENSUAL             --
--					 CRUZADA				   --
--                                             --
-------------------------------------------------

CREATE OR ALTER PROCEDURE report.sp_ReporteRecaudacionMensual
    @IdConsorcio INT,
    @Anio INT,
    @IdUF INT = NULL -- Parametro opcional para filtrar una UF específica
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos que el consorcio exista
    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El Consorcio indicado no existe.';
        RETURN;
    END

    PRINT 'Generando reporte de recaudación cruzada...';

    SELECT 
        -- Buscamos la UF
        uf.IdUF,
        uf.Piso + ' - ' + uf.Depto AS UnidadFuncional,
        p_per.Nombre + ' ' + p_per.Apellido AS Propietario,

        -- Columnas Dinamicas (Pivot Manual)
        -- Sumamos el importe SOLO si el mes de la fecha coincide con la columna

        SUM(CASE WHEN MONTH(p.Fecha) = 1 THEN p.Importe ELSE 0 END) AS Ene,
        SUM(CASE WHEN MONTH(p.Fecha) = 2 THEN p.Importe ELSE 0 END) AS Feb,
        SUM(CASE WHEN MONTH(p.Fecha) = 3 THEN p.Importe ELSE 0 END) AS Mar,
        SUM(CASE WHEN MONTH(p.Fecha) = 4 THEN p.Importe ELSE 0 END) AS Abr,
        SUM(CASE WHEN MONTH(p.Fecha) = 5 THEN p.Importe ELSE 0 END) AS May,
        SUM(CASE WHEN MONTH(p.Fecha) = 6 THEN p.Importe ELSE 0 END) AS Jun,
        SUM(CASE WHEN MONTH(p.Fecha) = 7 THEN p.Importe ELSE 0 END) AS Jul,
        SUM(CASE WHEN MONTH(p.Fecha) = 8 THEN p.Importe ELSE 0 END) AS Ago,
        SUM(CASE WHEN MONTH(p.Fecha) = 9 THEN p.Importe ELSE 0 END) AS Sep,
        SUM(CASE WHEN MONTH(p.Fecha) = 10 THEN p.Importe ELSE 0 END) AS Oct,
        SUM(CASE WHEN MONTH(p.Fecha) = 11 THEN p.Importe ELSE 0 END) AS Nov,
        SUM(CASE WHEN MONTH(p.Fecha) = 12 THEN p.Importe ELSE 0 END) AS Dic,
        
        -- Total Anual de esa UF
        SUM(p.Importe) AS TotalAnual

    FROM 
        consorcio.UnidadFuncional uf
    -- Usamos LEFT JOIN para que aparezcan las UF aunque no hayan pagado nada (filas en cero)
    LEFT JOIN 
        Pago.Pago p ON uf.IdUF = p.IdUF AND YEAR(p.Fecha) = @Anio
    LEFT JOIN
        consorcio.Persona p_per ON p_per.idUF = uf.IdUF -- Para mostrar el nombre (opcional pero útil)
        
    WHERE 
        uf.IdConsorcio = @IdConsorcio
        AND (@IdUF IS NULL OR uf.IdUF = @IdUF) -- Filtro opcional del 3er parámetro

    GROUP BY 
        uf.IdUF, uf.Piso, uf.Depto, p_per.Nombre, p_per.Apellido
    
    ORDER BY 
        uf.IdUF; -- Ordenamos por ID para mantener el orden de los departamentos
END
GO

--PARA PROBARLO

EXEC report.sp_ReporteRecaudacionMensual
    @IdConsorcio = 6, 
    @Anio = 2025;


-------------------------------------------------
--											   --
--		       RECAUDACION POR                 --
--				 PROCEDENCIA			       --
--                                             --
-------------------------------------------------

--EN ESTE SP UTILIZAMOS FORMATOXML PARA DARLE OPCION DE DEVOLVER LA EJECUCION EN FORMATO XML TAL COMO SOLICITA LA CONSIGNA

CREATE OR ALTER PROCEDURE report.sp_ReporteRecaudacionProcedencia
@IdConsorcio INT,
    @Anio INT,
    @FormatoXML BIT = 0 -- 0 = Output normal, 1 = Formato XML
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validar Consorcio
    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El Consorcio no existe';
        RETURN;
    END

    -- 2. Crear tabla temporal para guardar el resultado procesado
    CREATE TABLE #ReporteFinal (
        Anio INT,
        Mes INT,
        NombreMes NVARCHAR(20),
        RecaudacionOrdinaria DECIMAL(12,2),
        RecaudacionExtraordinaria DECIMAL(12,2),
        TotalRecaudado DECIMAL(12,2)
    );

    -- 3. Calcular y llenar la tabla temporal
    ;WITH DesglosePagos AS (
        SELECT
            p.Fecha,
            -- Calculo Proporcional Ordinario
            CASE 
                WHEN (ISNULL(pr.ExpensaOrdinaria,0) + ISNULL(pr.ExpensaExtraordinaria,0)) = 0 THEN p.Importe
                ELSE p.Importe * (ISNULL(pr.ExpensaOrdinaria,0) / (ISNULL(pr.ExpensaOrdinaria,0) + ISNULL(pr.ExpensaExtraordinaria,0)))
            END AS PagoOrd,
            -- Calculo Proporcional Extraordinario
            CASE 
                WHEN (ISNULL(pr.ExpensaOrdinaria,0) + ISNULL(pr.ExpensaExtraordinaria,0)) = 0 THEN 0
                ELSE p.Importe * (ISNULL(pr.ExpensaExtraordinaria,0) / (ISNULL(pr.ExpensaOrdinaria,0) + ISNULL(pr.ExpensaExtraordinaria,0)))
            END AS PagoExt
        FROM 
            Pago.Pago p
        INNER JOIN expensas.Prorrateo pr ON p.NroExpensa = pr.NroExpensa AND p.IdUF = pr.IdUF
        INNER JOIN expensas.Expensa e ON pr.NroExpensa = e.nroExpensa
        WHERE 
            e.idConsorcio = @IdConsorcio
            AND YEAR(p.Fecha) = @Anio
    )
    
    -- Insertamos el agrupado en la tabla temporal
    INSERT INTO #ReporteFinal (Anio, Mes, NombreMes, RecaudacionOrdinaria, RecaudacionExtraordinaria, TotalRecaudado)
    SELECT
        YEAR(Fecha) AS Anio,
        MONTH(Fecha) AS Mes,
        UPPER(LEFT(FORMAT(Fecha, 'MMMM', 'es-ES'), 1)) + SUBSTRING(FORMAT(Fecha, 'MMMM', 'es-ES'), 2, 20) AS NombreMes,
        CAST(SUM(PagoOrd) AS DECIMAL(12,2)),
        CAST(SUM(PagoExt) AS DECIMAL(12,2)),
        CAST(SUM(PagoOrd + PagoExt) AS DECIMAL(12,2))
    FROM 
        DesglosePagos
    GROUP BY 
        YEAR(Fecha), MONTH(Fecha), FORMAT(Fecha, 'MMMM', 'es-ES'); --el FORMAT lo utilizamos para mostrar los meses en Español
                                                                   --por default, SQL esta configurado en us-en
    -- 4. Mostrar la salida según el formato pedido
    IF @FormatoXML = 1
    BEGIN
        SELECT * FROM #ReporteFinal 
        ORDER BY Anio, Mes
        FOR XML PATH('Periodo'), ROOT('RecaudacionPorOrigen');
    END
    ELSE
    BEGIN
        SELECT * FROM #ReporteFinal 
        ORDER BY Anio, Mes;
    END

    -- Limpieza de la tabla tmp
    DROP TABLE #ReporteFinal;
END
GO

-- Para probarlo

-- Como output normal
EXEC report.sp_ReporteRecaudacionProcedencia @IdConsorcio = 6, @Anio = 2025, @FormatoXML = 0;

-- Formato XML
EXEC report.sp_ReporteRecaudacionProcedencia @IdConsorcio = 6, @Anio = 2025, @FormatoXML = 1;


-------------------------------------------------
--											   --
--		    TOP 5 INGRESOS Y GASTOS            --
--                                             --
-------------------------------------------------

CREATE OR ALTER PROCEDURE report.sp_ReporteTopMeses
    @IdConsorcio INT,
    @Anio INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos el consorcio

    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El consorcio no existe';
        RETURN;
    END

    PRINT ' ';
    PRINT '--- TOP 5 MESES DE MAYORES INGRESOS ---';
    PRINT ' ';
    
    -- 1. Top 5 Ingresos (Recaudacion)

    SELECT TOP 5
        'MAYORES INGRESOS' AS Categoria,
        YEAR(p.Fecha) AS Anio,
        MONTH(p.Fecha) AS Mes,
        UPPER(LEFT(FORMAT(p.Fecha, 'MMMM', 'es-ES'), 1)) + SUBSTRING(FORMAT(p.Fecha, 'MMMM', 'es-ES'), 2, 20) AS NombreMes,
        CAST(SUM(p.Importe) AS DECIMAL(12,2)) AS Total
    FROM 
        Pago.Pago p
    INNER JOIN 
        consorcio.UnidadFuncional uf ON p.IdUF = uf.IdUF
    WHERE 
        uf.IdConsorcio = @IdConsorcio
        AND YEAR(p.Fecha) = @Anio
    GROUP BY 
        YEAR(p.Fecha), MONTH(p.Fecha), FORMAT(p.Fecha, 'MMMM', 'es-ES')
    ORDER BY 
        SUM(p.Importe) DESC;

    PRINT ' ';
    PRINT '--- TOP 5 MESES DE MAYORES GASTOS ---';
    PRINT ' ';

    -- 2. Top 5 Egresos (Gastos)
    SELECT TOP 5
        'MAYORES GASTOS' AS Categoria,
        YEAR(g.fechaEmision) AS Anio,
        MONTH(g.fechaEmision) AS Mes,
        UPPER(LEFT(FORMAT(g.fechaEmision, 'MMMM', 'es-ES'), 1)) + SUBSTRING(FORMAT(g.fechaEmision, 'MMMM', 'es-ES'), 2, 20) AS NombreMes,
        CAST(SUM(g.importe) AS DECIMAL(12,2)) AS Total
    FROM 
        gastos.Gasto g
    WHERE 
        g.idConsorcio = @IdConsorcio
        AND YEAR(g.fechaEmision) = @Anio
    GROUP BY 
        YEAR(g.fechaEmision), MONTH(g.fechaEmision), FORMAT(g.fechaEmision, 'MMMM', 'es-ES')
    ORDER BY 
        SUM(g.importe) DESC;
END
GO

--Probamos

EXEC report.sp_ReporteTopMeses @IdConsorcio = 6, @Anio = 2025;


-------------------------------------------------
--											   --
--		         TOP 3 MOROSOS                 --
--                                             --
-------------------------------------------------

--EN ESTE SP UTILIZAMOS FORMATOXML PARA DARLE OPCION DE DEVOLVER LA EJECUCION EN FORMATO XML TAL COMO SOLICITA LA CONSIGNA

CREATE OR ALTER PROCEDURE report.sp_ReporteTopMorosos
    @IdConsorcio INT,
    @FormatoXML BIT = 0 -- 0 = Output normal, 1 = Formato XML
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validar Consorcio
    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El Consorcio no existe';
        RETURN;
    END

    -- 2. Crear tabla temporal para guardar el ranking
    CREATE TABLE #RankingMorosos (
        DNI VARCHAR(10),
        Nombre VARCHAR(30),
        Apellido VARCHAR(30),
        Email VARCHAR(40),
        Telefono VARCHAR(15),
        UnidadFuncional NVARCHAR(25),
        DeudaTotal DECIMAL(12,2),
        CantidadExpensasAdeudadas INT
    );

    -- 3. Calcular e insertar los TOP 3 morosos
    INSERT INTO #RankingMorosos (DNI, Nombre, Apellido, Email, Telefono, UnidadFuncional, DeudaTotal, CantidadExpensasAdeudadas)
    SELECT TOP 3
        p.DNI,
        p.Nombre,
        p.Apellido,
        ISNULL(p.Email, 'No informado'),
        ISNULL(p.Telefono, 'No informado'),
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
        p.DNI, p.Nombre, p.Apellido, p.Email, p.Telefono, uf.Piso, uf.Depto
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
        PRINT 'Generando reporte en formato XML...';
        
        SELECT 
            DNI AS "@DNI", -- DNI como atributo
            Nombre,
            Apellido,
            Email,
            Telefono,
            UnidadFuncional,
            DeudaTotal,
            CantidadExpensasAdeudadas
        FROM 
            #RankingMorosos
        FOR XML PATH('Moroso'), ROOT('Top3Morosos');
    END
    ELSE
    BEGIN
        -- Salida Tabla tradicional
        SELECT * FROM #RankingMorosos;
    END

    -- Limpieza tabla tmp
    DROP TABLE #RankingMorosos;
END
GO

-- Para probarlo

-- Como output normal
EXEC report.sp_ReporteTopMorosos @IdConsorcio = 8, @FormatoXML = 0;

-- Formato XML
EXEC report.sp_ReporteTopMorosos @IdConsorcio = 7, @FormatoXML = 1;


-------------------------------------------------
--											   --
--		      DIF DIAS ENTRE PAGOS             --
--                                             --
-------------------------------------------------


CREATE OR ALTER PROCEDURE report.sp_ReporteDiasEntrePagos
    @IdConsorcio INT,
    @FechaInicio DATE = NULL, -- Opcional: para acotar el reporte
    @FechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos el Consorcio
    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El Consorcio no existe';
        RETURN;
    END

    PRINT 'Calculando frecuencia de pagos...';

    -- Obtenemos los pagos y calculamos la fecha anterior
    ;WITH CalculoFechas AS (
        SELECT 
            uf.IdUF,
            uf.Piso + ' - ' + uf.Depto AS UnidadFuncional,
            p.IdPago,
            p.Fecha AS FechaPagoActual,
            -- LAG: Busca la fecha del pago ANTERIOR de esta misma UF
            LAG(p.Fecha) OVER (PARTITION BY uf.IdUF ORDER BY p.Fecha) AS FechaPagoAnterior
        FROM 
            Pago.Pago p
        INNER JOIN 
            consorcio.UnidadFuncional uf ON p.IdUF = uf.IdUF
        WHERE 
            uf.IdConsorcio = @IdConsorcio
    )

    -- Calculamos la diferencia
    SELECT 
        UnidadFuncional,
        FechaPagoActual, --Ponemos Primer Pago cuando el valor es NULL, ya que no existen pagos previos al primer pago de cada inquilino
        ISNULL(CONVERT(VARCHAR, FechaPagoAnterior), 'Primer Pago') AS FechaPagoAnterior,
        -- DATEDIFF: Calcula los días entre las dos fechas, si hay pagos el mismo dia ponemos 0
        CASE 
            WHEN FechaPagoAnterior IS NULL THEN 0 
            ELSE DATEDIFF(DAY, FechaPagoAnterior, FechaPagoActual) 
        END AS DiasTranscurridos
    FROM 
        CalculoFechas
    WHERE 
        -- Aplicamos el filtro de fechas al final sobre el resultado calculado
        (@FechaInicio IS NULL OR FechaPagoActual >= @FechaInicio)
        AND (@FechaFin IS NULL OR FechaPagoActual <= @FechaFin)
    ORDER BY 
        UnidadFuncional, FechaPagoActual;
END
GO

--Probamos

-- Ver el historial completo
EXEC report.sp_ReporteDiasEntrePagos @IdConsorcio = 6; 

-- ver solo un periodo especifico
EXEC report.sp_ReporteDiasEntrePagos 
    @IdConsorcio = 7, 
    @FechaInicio = '2025-01-01', 
    @FechaFin = '2025-12-31';

