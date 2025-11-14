/* -----------------------------------------------------------
   FUNCIONES GENÉRICAS DE CIFRADO Y DESCRIPFADO
   Usan ENCRYPTBYPASSPHRASE y DECRYPTBYPASSPHRASE con una
   passphrase fija. Aplicables a cualquier tabla o columna.
----------------------------------------------------------- */
-----------------------------------------------------------
-- Creación del esquema de seguridad
-----------------------------------------------------------
CREATE SCHEMA seguridad;
GO

-----------------------------------------------------------
-- Función para ENCRIPTAR
-----------------------------------------------------------
CREATE OR ALTER FUNCTION seguridad.EncryptData
(
    @plaintext NVARCHAR(MAX)     -- Texto en claro a cifrar
)
RETURNS VARBINARY(MAX)
AS
BEGIN
    DECLARE @encrypted VARBINARY(MAX);

    /* 
       ENCRYPTBYPASSPHRASE:
       - Cifra datos usando una clave (passphrase)
       - Devuelve varbinary(max)
       - Adecuado para proteger datos personales/sensibles
    */
    SET @encrypted = ENCRYPTBYPASSPHRASE('9122018RIV3BOC1', @plaintext);

    RETURN @encrypted;
END;
GO


-----------------------------------------------------------
-- Función para DESENCRIPTAR
-----------------------------------------------------------
CREATE OR ALTER FUNCTION seguridad.DecryptData
(
    @cipher VARBINARY(MAX)       -- Texto cifrado a descifrar
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @decrypted NVARCHAR(MAX);

    /* 
       DECRYPTBYPASSPHRASE:
       - Requiere la misma passphrase utilizada en el cifrado
       - Devuelve varbinary, por eso se convierte a NVARCHAR
       - Si el valor no corresponde a un cifrado válido, retorna NULL
    */
    SET @decrypted = CONVERT(NVARCHAR(MAX),
                             DECRYPTBYPASSPHRASE('9122018RIV3BOC1', @cipher)
                            );

    RETURN @decrypted;
END;
GO
/*TESTING*/
select p.DNI, p.Nombre, seguridad.EncryptData(p.Nombre) as encriptado,seguridad.DecryptData(seguridad.EncryptData(p.Nombre)) as desencriptado from consorcio.Persona p