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

USE master;
GO

-- 1. Permitir ver opciones avanzadas
sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- 2. Habilitar procedimientos de automatización OLE (Para la API)
sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO



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

-------------------------------------------------
--											   --
--		         TOP 3 MOROSOS                 --
--                                             --
-------------------------------------------------
-- Aseguramos el contexto de la base de datos
USE Com5600G07;
GO

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
        Email VARCHAR(40),
        Telefono VARCHAR(15),
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
GO

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

-------------------------------------------------
--											   --
--		    REPORTES VIA MAIL (API)            --
--                                             --
-------------------------------------------------
--Se utilizo el reporte generado en el reporte 5 con el objetivo de simular una comunicacion con el estudio juridico para informar morosos


CREATE OR ALTER PROCEDURE report.sp_EnviarReportePorEmail
@IdConsorcio INT,
    @EmailDestino VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NombreConsorcio NVARCHAR(100);
    DECLARE @XmlData XML; -- Acá vamos a recibir el dato
    DECLARE @HtmlRows NVARCHAR(MAX);
    DECLARE @HtmlBody NVARCHAR(MAX);
    DECLARE @JsonPayload NVARCHAR(MAX);
    DECLARE @Object INT, @Status INT, @HRESULT INT;
    DECLARE @ResponseText VARCHAR(8000);
    DECLARE @UrlAPI VARCHAR(200) = 'https://api.brevo.com/v3/smtp/email';
    DECLARE @ApiKey VARCHAR(200) = 'PONER API KEY ACA';
                                --Aca ponemos nuestra API key de brevo, en caso de necesitar levantarla nuevamente
                                --esta backupeada en el archivo apikey.txt
                            --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

    -- Validamos el consorcio
    IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
    BEGIN
        PRINT 'El Consorcio no existe';
        RETURN;
    END
    SELECT @NombreConsorcio = NombreConsorcio FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio;

    PRINT 'Obteniendo datos de morosos...';

    -- Inicializamos la variable para que el SP sepa que queremos el output XML
    SET @XmlData = ''; 
    
    EXEC report.sp_ReporteTopMorosos 
        @IdConsorcio = @IdConsorcio, 
        @FormatoXML = 1, 
        @XmlSalida = @XmlData OUTPUT;

    -- Validar si volvio vacío
    IF CAST(@XmlData AS NVARCHAR(MAX)) = '' OR @XmlData IS NULL
    BEGIN
        PRINT 'No hay morosos para informar (XML Vacío). No se envía mail.';
        RETURN;
    END

    -- Construimos HTML a partir del XML recibido
SET @HtmlRows = CAST((
        SELECT 
            td = T.c.value('@DNI', 'VARCHAR(20)'), '',
            
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; white-space: nowrap; font-weight: bold;', 
            td = T.c.value('(Nombre)[1]', 'VARCHAR(50)') + ' ' + T.c.value('(Apellido)[1]', 'VARCHAR(50)'), '',
            
            -- white-space: nowrap para que no haga corte de linea
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; white-space: nowrap;',
            td = T.c.value('(UnidadFuncional)[1]', 'VARCHAR(20)'), '',
            
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; color: #d9534f; text-align: right; white-space: nowrap;',
            td = '$ ' + FORMAT(CAST(T.c.value('(DeudaTotal)[1]', 'VARCHAR(20)') AS DECIMAL(12,2)), 'N2', 'es-AR'), '',
           
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; font-size: 12px; color: #666;',
            td = T.c.value('(Email)[1]', 'VARCHAR(50)') + '[SALTO] Tel.: ' + T.c.value('(Telefono)[1]', 'VARCHAR(20)')
            
        FROM @XmlData.nodes('/Top3Morosos/Moroso') T(c)
        FOR XML PATH('tr'), TYPE
    ) AS NVARCHAR(MAX));

    SET @HtmlRows = REPLACE(@HtmlRows, '[SALTO]', '<br>');
    --convertimos [SALTO] en una etiqueta break para forzar un salto de linea ya que dentro de FOR XML
    --no podemos utilizar la etiqueta ya que lo convierte a texto, es por esto que usamos un placeholder

    -- Armamos el cuerpo completo (Contenedor tipo Tarjeta)
SET @HtmlBody = 
        '<!DOCTYPE html>
        <html>
        <body style="font-family: ''Helvetica Neue'', Helvetica, Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
            <div style="max-width: 700px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);">
                
                <div style="border-bottom: 2px solid #0056b3; padding-bottom: 10px; margin-bottom: 20px;">
                    <h2 style="color: #333; margin: 0;">Reporte de Morosidad</h2>
                    <p style="color: #666; margin: 5px 0 0 0;">Consorcio: <strong>' + @NombreConsorcio + '</strong></p>
                </div>

                <p style="color: #555; line-height: 1.5;">Estimados,</p>
                <p style="color: #555; line-height: 1.5;">Se adjunta el listado de los <strong>3 mayores deudores</strong> al día de la fecha para iniciar las gestiones de cobranza judicial.</p>

                <table style="width: 100%; border-collapse: collapse; margin: 25px 0; font-size: 14px;">
                    <thead>
                        <tr style="background-color: #0056b3; color: #ffffff; text-align: left;">
                            <th style="padding: 12px;">DNI</th>
                            <th style="padding: 12px;">Nombre</th>
                            <th style="padding: 12px;">UF</th>
                            <th style="padding: 12px; text-align: right;">Deuda Total</th>
                            <th style="padding: 12px;">Contacto</th>
                        </tr>
                    </thead>
                    <tbody>' + 
                        ISNULL(@HtmlRows, '') + 
                    '</tbody>
                </table>

                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #999; text-align: center;">
                    <p>Este es un reporte automático generado por el <strong>Sistema de Gestión de Consorcios Altos de Saint Just</strong>.</p>
                    <p>Por favor no responder a este correo.</p>
                </div>
            </div>
        </body>
        </html>';

    -- Enviamos a Brevo
    SET @HtmlBody = REPLACE(@HtmlBody, '"', '\"');                                                
    SET @HtmlBody = REPLACE(REPLACE(@HtmlBody, CHAR(13), ''), CHAR(10), '');
    --en el payload esta cargado el mail con el que se creo la cuenta en brevo
     --no se puede enviar desde cualquier mail, la pagina solo reconoce el mail del usuario
    SET @JsonPayload = '{
        "sender": { "name": "Sistema Consorcio", "email": "agus_1871@hotmail.com" }, 
        "to": [ { "email": "' + @EmailDestino + '", "name": "Estudio Juridico" } ],
        "subject": "Derivación a Legales: Morosos ' + @NombreConsorcio + '",
        "htmlContent": "' + @HtmlBody + '"
    }';

    PRINT 'Enviando mail...';
    EXEC @HRESULT = sp_OACreate 'WinHttp.WinHttpRequest.5.1', @Object OUT;
    
    IF @HRESULT <> 0 
    BEGIN
        PRINT 'Error al crear objeto OLE Automation.';
        RETURN;
    END

    EXEC sp_OAMethod @Object, 'Open', NULL, 'POST', @UrlAPI, 'false';
    EXEC sp_OAMethod @Object, 'SetRequestHeader', NULL, 'api-key', @ApiKey;
    EXEC sp_OAMethod @Object, 'SetRequestHeader', NULL, 'Content-Type', 'application/json';
    EXEC sp_OAMethod @Object, 'Send', NULL, @JsonPayload;
    EXEC sp_OAMethod @Object, 'Status', @Status OUT;
    EXEC sp_OADestroy @Object;

    IF @Status = 201 PRINT 'EMAIL ENVIADO EXITOSAMENTE.';
    ELSE PRINT 'ERROR AL ENVIAR. Status: ' + CAST(@Status AS VARCHAR);
END
GO

