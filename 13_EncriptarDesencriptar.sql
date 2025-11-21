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
GO
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


/* -----------------------------------------------------------
   SCRIPT DE MIGRACIÓN: Encriptación + Columnas Hash
   Tabla: consorcio.Persona
----------------------------------------------------------- */

-- 1.1. Añadir columnas temporales (Encriptadas Y Hash)
ALTER TABLE consorcio.Persona
ADD Email_Encrypted VARBINARY(MAX) NULL,
    Telefono_Encrypted VARBINARY(MAX) NULL,
    CVU_Encrypted VARBINARY(MAX) NULL,
    
    -- NUEVO: Columnas para los Hashes indexables
    Email_Hash VARBINARY(32) NULL,
    CVU_Hash VARBINARY(32) NULL;
GO

-- 1.1b. Eliminar los VIEJOS índices de las columnas en texto plano
-- (Esto es necesario para poder dropear las columnas)
-- Usamos 'IF EXISTS' para evitar errores si ya se dropearon
DROP INDEX IF EXISTS IX_Persona_Email ON consorcio.Persona;
DROP INDEX IF EXISTS IX_Persona_CVU ON consorcio.Persona;
DROP INDEX IF EXISTS IX_Persona_idUF ON consorcio.Persona;
DROP INDEX IF EXISTS IX_Persona_idUF_DNI ON consorcio.Persona;
GO

-- 1.2. Encriptar Y HASHEAR los datos existentes
-- (Lee de las columnas de texto plano antes de que se eliminen)
UPDATE consorcio.Persona
SET 
    -- Columnas encriptadas (para ver el dato)
    Email_Encrypted = CASE WHEN Email IS NOT NULL THEN seguridad.EncryptData(Email) ELSE NULL END,
    Telefono_Encrypted = CASE WHEN Telefono IS NOT NULL THEN seguridad.EncryptData(Telefono) ELSE NULL END,
    CVU_Encrypted = CASE WHEN CVU IS NOT NULL THEN seguridad.EncryptData(CVU) ELSE NULL END,
    
    -- NUEVO: Columnas Hash (para buscar rápido)
    Email_Hash = CASE WHEN Email IS NOT NULL THEN HASHBYTES('SHA2_256', Email) ELSE NULL END,
    CVU_Hash = CASE WHEN CVU IS NOT NULL THEN HASHBYTES('SHA2_256', CVU) ELSE NULL END;
GO

-- 1.3. Eliminar las columnas originales (en texto plano)
ALTER TABLE consorcio.Persona
DROP COLUMN Email,
         COLUMN Telefono,
         COLUMN CVU;
GO

-- 1.4. Renombrar las nuevas columnas encriptadas a sus nombres originales
EXEC sp_rename 'consorcio.Persona.Email_Encrypted', 'Email', 'COLUMN';
EXEC sp_rename 'consorcio.Persona.Telefono_Encrypted', 'Telefono', 'COLUMN';
EXEC sp_rename 'consorcio.Persona.CVU_Encrypted', 'CVU', 'COLUMN';
GO

-- 1.5. NUEVO: Crear los índices sobre las columnas Hash
PRINT 'Creando nuevos índices en las columnas Hash...';

CREATE NONCLUSTERED INDEX IX_Persona_Email_Hash
ON consorcio.Persona (Email_Hash) 
WHERE Email_Hash IS NOT NULL; -- Mantenemos el filtro WHERE

CREATE NONCLUSTERED INDEX IX_Persona_CVU_Hash
ON consorcio.Persona (CVU_Hash)
WHERE CVU_Hash IS NOT NULL; -- Es buena práctica filtrar NULLs del índice
GO

PRINT 'Migración de consorcio.Persona completada (Encriptación + Hash).';
/* -----------------------------------------------------------
   PASO 2: MODIFICAR la tabla Pago.Pago
   (CuentaOrigen)
----------------------------------------------------------- */

/* -----------------------------------------------------------
   SCRIPT DE MIGRACIÓN: Encriptación + Columnas Hash
   Tabla: Pago.Pago
----------------------------------------------------------- */

-- 1.1. Añadir columnas temporales (Encriptada Y Hash)
ALTER TABLE Pago.Pago
ADD CuentaOrigen_Encrypted VARBINARY(MAX) NULL,
    
    -- NUEVO: Columna para el Hash indexable
    CuentaOrigen_Hash VARBINARY(32) NULL;
GO

-- 1.2. Encriptar Y HASHEAR los datos existentes
-- (Lee de la columna de texto plano antes de que se elimine)
-- La columna original era NOT NULL, así que procesamos todo.
UPDATE Pago.Pago
SET 
    -- Columna encriptada (para ver el dato)
    CuentaOrigen_Encrypted = seguridad.EncryptData(CuentaOrigen),
    
    -- NUEVO: Columna Hash (para buscar rápido)
    CuentaOrigen_Hash = HASHBYTES('SHA2_256', CuentaOrigen);
GO

-- 1.3. Eliminar la columna original (en texto plano)
DROP INDEX IF EXISTS IX_Pago_IdUF_Fecha_Completo ON Pago.Pago;

ALTER TABLE Pago.Pago
DROP COLUMN CuentaOrigen;
GO

-- 1.4. Renombrar la nueva columna encriptada a su nombre original
EXEC sp_rename 'Pago.Pago.CuentaOrigen_Encrypted', 'CuentaOrigen', 'COLUMN';
GO

-- 1.5. RE-APLICAR la restricción NOT NULL
-- (La original era NOT NULL, por lo que las nuevas también deben serlo)
ALTER TABLE Pago.Pago
ALTER COLUMN CuentaOrigen VARBINARY(MAX) NOT NULL;

ALTER TABLE Pago.Pago
ALTER COLUMN CuentaOrigen_Hash VARBINARY(32) NOT NULL;
GO

-- 1.6. NUEVO: Crear el índice sobre la columna Hash
PRINT 'Creando nuevo índice en la columna Hash...';

CREATE NONCLUSTERED INDEX IX_Pago_CuentaOrigen_Hash
ON Pago.Pago (CuentaOrigen_Hash);
GO

PRINT 'Migración de Pago.Pago completada (Encriptación + Hash).';
 
