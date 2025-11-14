USE Com5600G07

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

select p.DNI, p.Nombre, seguridad.EncryptData(p.Nombre) as encriptado,seguridad.DecryptData(seguridad.EncryptData(p.Nombre)) as desencriptado from consorcio.Persona p;


/* -----------------------------------------------------------
                 MODIFICAR CAMPOS, TODO ENCRIPTADO
----------------------------------------------------------- *//

-- 1.1. Añadir columnas temporales para los datos encriptados
ALTER TABLE consorcio.Persona
ADD Email_Encrypted VARBINARY(MAX) NULL,
    Telefono_Encrypted VARBINARY(MAX) NULL,
    CVU_Encrypted VARBINARY(MAX) NULL;
GO

-- 1.2. Encriptar los datos existentes y moverlos a las nuevas columnas
-- (Solo encripta si el valor no es NULL)
UPDATE consorcio.Persona
SET 
    Email_Encrypted = CASE WHEN Email IS NOT NULL THEN seguridad.EncryptData(Email) ELSE NULL END,
    Telefono_Encrypted = CASE WHEN Telefono IS NOT NULL THEN seguridad.EncryptData(Telefono) ELSE NULL END,
    CVU_Encrypted = CASE WHEN CVU IS NOT NULL THEN seguridad.EncryptData(CVU) ELSE NULL END;
GO

-- 1.3. Eliminar las columnas originales (en texto plano)
ALTER TABLE consorcio.Persona
DROP COLUMN Email,
            COLUMN Telefono,
            COLUMN CVU;
GO

-- 1.4. Renombrar las nuevas columnas a sus nombres originales
EXEC sp_rename 'consorcio.Persona.Email_Encrypted', 'Email', 'COLUMN';
EXEC sp_rename 'consorcio.Persona.Telefono_Encrypted', 'Telefono', 'COLUMN';
EXEC sp_rename 'consorcio.Persona.CVU_Encrypted', 'CVU', 'COLUMN';
GO

/* -----------------------------------------------------------
   PASO 2: MODIFICAR la tabla Pago.Pago
   (CuentaOrigen)
----------------------------------------------------------- */

-- 2.1. Añadir columna temporal
ALTER TABLE Pago.Pago
ADD CuentaOrigen_Encrypted VARBINARY(MAX) NULL;
GO

-- 2.2. Encriptar datos existentes
-- La columna original era NOT NULL, por lo que encriptamos todo
UPDATE Pago.Pago
SET 
    CuentaOrigen_Encrypted = seguridad.EncryptData(CuentaOrigen);
GO

-- 2.3. Eliminar la columna original
ALTER TABLE Pago.Pago
DROP COLUMN CuentaOrigen;
GO

-- 2.4. Renombrar la nueva columna
EXEC sp_rename 'Pago.Pago.CuentaOrigen_Encrypted', 'CuentaOrigen', 'COLUMN';
GO

-- 2.5. RE-APLICAR la restricción NOT NULL que tenía la columna original
ALTER TABLE Pago.Pago
ALTER COLUMN CuentaOrigen VARBINARY(MAX) NOT NULL;
GO

PRINT 'Migración a columnas encriptadas completada.';

