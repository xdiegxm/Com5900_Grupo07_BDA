-- 1. Primero verificar que tenemos los datos correctos del Excel
SELECT 'Datos en el archivo Excel:' as Mensaje;
SELECT 
    [Consorcio],
    [Nombre del consorcio],
    [Domicilio],
    [Cant unidades funcionales],
    [m2 totales]
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Archivos_para_el_TP\datos varios.xlsx;HDR=YES',
    'SELECT * FROM [Consorcios$]'
);
-- Insertar solo las columnas que coinciden, proporcionando valores para las columnas NOT NULL
INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO)
SELECT 
    [Nombre del consorcio] AS NombreConsorcio, 
    [Domicilio] AS Direccion,
    [m2 totales] AS Superficie_Total,
    0 AS MoraPrimerVTO,  -- Valor por defecto para columnas NOT NULL
    0 AS MoraProxVTO     -- Valor por defecto para columnas NOT NULL
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Archivos_para_el_TP\datos varios.xlsx;HDR=YES',
    'SELECT * FROM [Consorcios$]'
);

-- Verificar que se insertaron correctamente
SELECT 'Datos insertados en la tabla consorcio.Consorcio:' as Mensaje;
SELECT * FROM consorcio.Consorcio;


