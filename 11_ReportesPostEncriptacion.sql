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
-- Comerci Salcedo, Francisco Ivan             --
-------------------------------------------------
USE Com5600G07

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

/*EXEC report.sp_ReporteTopMorosos @IdConsorcio = 1, @FormatoXML = 0;*/
select * from expensas.Prorrateo

/* API MAIL*/

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
    -- (La ApiKey se mantiene, no es necesario cambiarla)
    DECLARE @ApiKey VARCHAR(200) = 'PONER API KEY ACA'; 

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
            
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; white-space: nowrap;',
            td = T.c.value('(UnidadFuncional)[1]', 'VARCHAR(20)'), '',
            
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; color: #d9534f; text-align: right; white-space: nowrap;',
            td = '$ ' + FORMAT(CAST(T.c.value('(DeudaTotal)[1]', 'VARCHAR(20)') AS DECIMAL(12,2)), 'N2', 'es-AR'), '',
            
            'td/@style' = 'padding: 12px; border-bottom: 1px solid #ddd; font-size: 12px; color: #666;',
            
            -- ------ INICIO DE LA CORRECCIÓN ------
            -- Leemos los valores como NVARCHAR para que coincidan con la salida
            -- del SP de morosos (que usa DecryptData)
            td = T.c.value('(Email)[1]', 'NVARCHAR(100)') + '[SALTO] Tel.: ' + T.c.value('(Telefono)[1]', 'NVARCHAR(30)')
            -- ------ FIN DE LA CORRECCIÓN ------
            
        FROM @XmlData.nodes('/Top3Morosos/Moroso') T(c)
        FOR XML PATH('tr'), TYPE
    ) AS NVARCHAR(MAX));

    SET @HtmlRows = REPLACE(@HtmlRows, '[SALTO]', '<br>');

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

/*EXEC report.sp_EnviarReportePorEmail 
    @IdConsorcio = 5, 
    @EmailDestino = 'agustinpe45@gmail.com';*/ --aca ponemos el mail al que queremos mandar el reporte (se puede usar cualquiera)
                                             --simulando el contacto con el estudio juridico
; 
