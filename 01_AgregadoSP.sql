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
-- Pi�ero, Agust�n                             --
-- Nardelli Rosales, Cecilia Anahi             --
-- Comerci Salcedo, Francisco Ivan             --
-------------------------------------------------

-------------------------------------------------
--											   --
--		  STORED PROCEDURES AGREGADOS          --
--											   --
-------------------------------------------------

USE master
USE Com5600G07
GO

-- Tabla Consorcio
CREATE OR ALTER PROCEDURE consorcio.sp_agrConsorcio
	@nombreconsorcio VARCHAR(40),
    @direccion NVARCHAR(100),
    @superficie_total DECIMAL(10,2),
    @moraprimervto DECIMAL(5,2),
    @moraproxvto DECIMAL(5,2)
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
            DECLARE @id INT;
            -- Validamos que no exista un consorcio con el mismo nombre y direcci�n
            SELECT @id = IdConsorcio
            FROM consorcio.Consorcio
            WHERE NombreConsorcio = @nombreconsorcio AND Direccion = @direccion;

            IF @id IS NOT NULL
            BEGIN
                PRINT('Ya existe un consorcio con el mismo nombre y direccion.');
                RETURN @id;
            END 

            -- Validamos y limpiamos cadenas

            IF @nombreconsorcio = '' OR LEN(@nombreconsorcio) > 40
            BEGIN 
                PRINT('El nombre del consorcio no es valido.');
                RAISERROR('.',16,1);
            END
            SET @nombreconsorcio = TRIM(@nombreconsorcio);

            IF @direccion = '' OR LEN(@direccion) > 100
            BEGIN
                PRINT('La direccion no es valida.');
                RAISERROR('.',16,1);
            END
            SET @direccion = TRIM(@direccion);
             
            -- Validaciones num�ricas
            IF @superficie_total IS NULL OR @superficie_total <=0
            BEGIN
                PRINT('La superficie total debe ser mayor a 0.');
                RAISERROR('.',16,1);
            END

            IF @moraprimervto IS NULL OR @moraprimervto<0
            BEGIN
                PRINT('La mora del primer vencimiento no puede ser negativa.');
                RAISERROR('.',16,1);
            END

            IF @moraproxvto IS NULL OR @moraproxvto<0
            BEGIN
                PRINT('La mora del proximo vencimiento no puede ser negativa.');
                RAISERROR('.',16,1);
            END
    END TRY    
    
    BEGIN CATCH
        IF ERROR_SEVERITY()>10
        BEGIN
            RAISERROR('Algo salio mal en el registro del consorcio.',16,1);
            RETURN;
        END
    END CATCH

    -- Insercion
    INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, MoraPrimerVTO, MoraProxVTO)
    VALUES (@NombreConsorcio, @Direccion, @Superficie_Total, @MoraPrimerVTO, @MoraProxVTO);

    SET @id = SCOPE_IDENTITY();
    RETURN @id;
END 
GO

    
--Tabla Persona
CREATE OR ALTER PROCEDURE consorcio.sp_agrPersona
    @DNI VARCHAR(10),
    @Nombre VARCHAR(30),
    @Apellido VARCHAR(30),
    @Email VARCHAR(40),
    @Telefono VARCHAR(15),
    @CVU CHAR(22)
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        DECLARE @ExisteDNI VARCHAR(10);

        -- Validamos que no exista una persona con el mismo DNI
        SELECT @ExisteDNI = DNI
        FROM consorcio.Persona
        WHERE DNI = @DNI;

        IF @ExisteDNI IS NOT NULL
        BEGIN
            PRINT('Ya existe una persona con el DNI ingresado.')
            RETURN;
        END

        -- Validaci�n y limpieza de campos
        --DNI
        IF @DNI = '' OR @DNI LIKE '%[^0-9]%' OR LEN(@DNI)>10
        BEGIN
            PRINT('El DNI no es valido.');
            RAISERROR('.',16,1);
        END
        SET @DNI=TRIM(@DNI);

        --Nombre
        IF @Nombre='' OR @Nombre LIKE '%[^a-zA-Z ]%' OR LEN(@Nombre)>30
        BEGIN
            PRINT('Nombre ingresado no valido.');
            RAISERROR('.',16,1);
        END
        SET @Nombre = TRIM(@Nombre);

        --Apellido
        IF @Apellido='' OR @Apellido LIKE '%[^a-zA-Z ]%' OR LEN(@Apellido) >30
        BEGIN
            PRINT('Apellido ingresado no valido.');
            RAISERROR('.',16,1);
        END
        SET @Apellido = TRIM(@Apellido);

        -- Email
        IF @Email IS NOT NULL AND @Email <> ''
        BEGIN
            IF @Email NOT LIKE '%@%.%' OR LEN(@Email) > 40
            BEGIN
                PRINT('El correo electr�nico no es v�lido.');
                RAISERROR('.', 16, 1);
            END
            SET @Email = TRIM(@Email);
        END

        -- Tel�fono
        IF @Telefono IS NOT NULL AND @Telefono <> ''
        BEGIN
            IF @Telefono LIKE '%[^0-9]%' OR LEN(@Telefono) > 15
            BEGIN
                PRINT('El tel�fono no es v�lido.');
                RAISERROR('.', 16, 1);
            END
            SET @Telefono = TRIM(@Telefono);
        END

        -- CVU
        IF @CVU IS NOT NULL AND @CVU <> ''
        BEGIN
            IF @CVU LIKE '%[^0-9]%' OR LEN(@CVU) <> 22
            BEGIN
                PRINT('El CVU debe tener exactamente 22 d�gitos num�ricos.');
                RAISERROR('.', 16, 1);
            END
        END
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY()>10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la persona',16,1);
            RETURN;
        END
    END CATCH

    -- Inserci�n del registro --
    INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU)
    VALUES (@DNI, @Nombre, @Apellido, @Email, @Telefono, @CVU);
END 
GO

IF OBJECT_ID('consorcio.UnidadFuncional','U') IS NULL
BEGIN
    CREATE TABLE consorcio.UnidadFuncional(
        IdUF INT IDENTITY(1,1) PRIMARY KEY,
        Piso NVARCHAR(10) NOT NULL,
        Depto NVARCHAR(10) NOT NULL,
        Superficie DECIMAL(6,2) NOT NULL CHECK(Superficie>0),
        Coeficiente DECIMAL(5,2) NOT NULL CHECK(Coeficiente>0 AND Coeficiente<=100),
        IdConsorcio INT NOT NULL,
        Propietario VARCHAR(10) NOT NULL,
        FOREIGN KEY(Propietario) REFERENCES consorcio.Persona(DNI),
        FOREIGN KEY(IdConsorcio) REFERENCES consorcio.Consorcio(IdConsorcio)
    );
END

--Tabla Unidad Funcional
CREATE OR ALTER PROCEDURE consorcio.so_agrUnidadFuncional
    @Piso NVARCHAR(10),
    @Depto NVARCHAR(10),
    @Superficie DECIMAL(6,2),
    @Coeficiente DECIMAL(5,2),
    @IdConsorcio INT,
    @Propietario VARCHAR(10)
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteConsorcio INT;
        DECLARE @ExistePropietario VARCHAR(10);
        DECLARE @IdExistente INT;

        --validamos que no exista una UF igual (mismo consorcio, piso y depto)
        SELECT @IdExistente = IdUF
        FROM consorcio.UnidadFuncional
        WHERE IdConsorcio = @IdConsorcio AND Piso = @Piso AND Depto = @Depto;

        IF @IdExistente IS NOT NULL
        BEGIN
            PRINT('Ya existe una unidad funcional con el mismo piso y depto en este consorcio.');
            RETURN;
        END

        --validamos que exista el consorcio
        SELECT @ExisteConsorcio = IdConsorcio
        FROM consorcio.Consorcio
        WHERE IdConsorcio = @IdConsorcio;

        IF @ExisteConsorcio IS NULL
        BEGIN
            PRINT('El consorcio indicado no existe.');
            RAISERROR('.', 16, 1);
        END

        --validamos que exista el propietario
        SELECT @ExistePropietario = DNI
        FROM consorcio.Persona
        WHERE DNI = @Propietario;

        IF @ExistePropietario IS NULL
        BEGIN
            PRINT('El propietario indicado no existe.');
            RAISERROR('.', 16, 1);
        END

        --validaciones de datos 
        IF @Piso = '' OR LEN(@Piso) > 10
        BEGIN
            PRINT('El piso no es valido.');
            RAISERROR('.', 16, 1);
        END
        SET @Piso = TRIM(@Piso);

        IF @Depto = '' OR LEN(@Depto) > 10
        BEGIN
            PRINT('El departamento no es valido.');
            RAISERROR('.', 16, 1);
        END
        SET @Depto = TRIM(@Depto);

        IF @Superficie IS NULL OR @Superficie <= 0
        BEGIN
            PRINT('La superficie debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

        IF @Coeficiente IS NULL OR @Coeficiente <= 0 OR @Coeficiente > 100
        BEGIN
            PRINT('El coeficiente debe ser mayor a 0 y menor o igual a 100.');
            RAISERROR('.', 16, 1);
        END
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la unidad funcional.', 16, 1);
            RETURN;
        END
    END CATCH

    --insercion de la nueva unidad funcional
    INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio, Propietario)
    VALUES (@Piso, @Depto, @Superficie, @Coeficiente, @IdConsorcio, @Propietario);
END
GO

--Tabla Ocupacion 
CREATE OR ALTER PROCEDURE consorcio.sp_agrOcupacion
    @Rol CHAR(11),
    @FechaInicio DATE,
    @FechaFin DATE = NULL,
    @iduf INT,
    @DNI VARCHAR(10)
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteUF INT;
        DECLARE @ExistePersona VARCHAR(10);
        DECLARE @IdExistente INT;

        --validar que el IdUF exista
        SELECT @ExisteUF = IdUF
        FROM consorcio.UnidadFuncional
        WHERE IdUF = @iduf;

        IF @ExisteUF IS NULL
        BEGIN
            PRINT('La unidad funcional no existe.');
            RAISERROR('1',16,1);
        END

        --validar que el DNI exista
        SELECT @ExistePersona = DNI
        FROM consorcio.Persona
        WHERE DNI = @DNI;

        IF @ExistePersona IS NULL
        BEGIN
            PRINT('La persona indicada no existe.');
            RAISERROR('.',16,1);
        END

        --validacion de rol 
        IF @Rol NOT IN ('Propietario','Inquilino')
        BEGIN
            PRINT('El rol debe ser Propietario o Inquilino');
            RAISERROR('.',16,1);
        END

        --validacion de fechas
        IF @FechaInicio IS NULL
        BEGIN
            PRINT('La fecha de inicio es obligatoria.');
            RAISERROR('.', 16, 1);
        END

        IF @FechaFin IS NOT NULL AND @FechaFin <= @FechaInicio
        BEGIN
            PRINT('La fecha de fin debe ser mayor que la fecha de inicio.');
            RAISERROR('.', 16, 1);
        END
    END TRY
     BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la ocupacion.', 16, 1);
            RETURN;
        END
    END CATCH

    -- Insertar ocupaci�n
    INSERT INTO consorcio.Ocupacion (Rol, FechaInicio, FechaFin, IdUF, DNI)
    VALUES (@Rol, @FechaInicio, @FechaFin, @IdUF, @DNI);
END
GO

--Tabla baulera
CREATE OR ALTER PROCEDURE consorcio.sp_agrBaulera
    @Tamanio DECIMAL(10,2),
    @IdUF INT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteUF INT;

        -- Validar que el IdUF exista
        SELECT @ExisteUF = IdUF
        FROM consorcio.UnidadFuncional
        WHERE IdUF = @IdUF;

        IF @ExisteUF IS NULL
        BEGIN
            PRINT('La unidad funcional indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validar tama�o
        IF @Tamanio IS NULL OR @Tamanio <= 0
        BEGIN
            PRINT('El tama�o debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la baulera.', 16, 1);
            RETURN;
        END
    END CATCH

    -- Insertar baulera
    INSERT INTO consorcio.Baulera (Tamanio, IdUF)
    VALUES (@Tamanio, @IdUF);

    PRINT('Baulera registrada correctamente.');
END
GO

--Tabla cochera
CREATE OR ALTER PROCEDURE consorcio.sp_agrCochera
    @Tamanio DECIMAL(10,2),
    @IdUF INT
AS
BEGIN
    BEGIN TRY
        DECLARE @IdCochera INT;

        -- Validaci�n de tamanio
        IF @Tamanio <= 0
        BEGIN
            PRINT('El tamanio de la cochera debe ser mayor a 0');
            RAISERROR('Tamanio invalido',16,1);
        END

        -- Verificaci�n de existencia de la Unidad Funcional
        IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
        BEGIN
            PRINT('La Unidad Funcional indicada no existe');
            RAISERROR('Unidad Funcional invalida',16,1);
        END

        -- Inserci�n
        INSERT INTO consorcio.Cochera (Tamanio, IdUF)
        VALUES (@Tamanio, @IdUF);
        SET @IdCochera = SCOPE_IDENTITY();
        RETURN @IdCochera;

    END TRY
    BEGIN CATCH
        PRINT('Ocurri� un error al registrar la cochera');
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage,16,1);
        RETURN;
    END CATCH
END
GO

--tabla Expensa
CREATE OR ALTER PROCEDURE expensas.sp_agrExpensa
    @Tipo CHAR(1),
    @NroExpensa INT,
    @Mes TINYINT,
    @Anio SMALLINT,
    @FechaEmision DATE,
    @Vencimiento DATE,
    @Total DECIMAL(12,2),
    @EstadoEnvio VARCHAR(20) = NULL,
    @MetodoEnvio VARCHAR(20) = NULL,
    @DestinoEnvio NVARCHAR(50) = NULL,
    @IdConsorcio INT
AS BEGIN
    BEGIN TRY
        --validaciones
                IF @Tipo NOT IN ('O','E')
        BEGIN
            RAISERROR('Tipo debe ser O (Ordinaria) o E (Extraordinaria)',16,1);
        END

        IF @Mes NOT BETWEEN 1 AND 12
        BEGIN
            RAISERROR('Mes debe estar entre 1 y 12',16,1);
        END

        IF @Anio < 2000
        BEGIN
            RAISERROR('A�o invalido',16,1);
        END

        IF @FechaEmision IS NULL OR @Vencimiento IS NULL OR @Vencimiento < @FechaEmision
        BEGIN
            RAISERROR('Fechas invalidas: Vencimiento debe ser >= FechaEmision',16,1);
        END

        IF @Total IS NULL OR @Total < 0
        BEGIN
            RAISERROR('Total debe ser mayor o igual a 0',16,1);
        END

        -- validar existencia del consorcio
        IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
        BEGIN
            RAISERROR('El consorcio indicado no existe',16,1);
        END

        --validar que no exista la expensa
        IF EXISTS (SELECT 1 FROM expensas.Expensa WHERE Tipo=@Tipo AND NroExpensa=@NroExpensa)
        BEGIN
            RAISERROR('Ya existe una expensa con el mismo Tipo y NroExpensa',16,1);
        END

        --insercion
        INSERT INTO expensas.Expensa
            (Tipo, NroExpensa, Mes, Anio, FechaEmision, Vencimiento, Total, EstadoEnvio, MetodoEnvio, DestinoEnvio, IdConsorcio)
        VALUES
            (@Tipo, @NroExpensa, @Mes, @Anio, @FechaEmision, @Vencimiento, @Total, @EstadoEnvio, @MetodoEnvio, @DestinoEnvio, @IdConsorcio);

        -- Retornar datos insertados
        SELECT Tipo, NroExpensa
        FROM expensas.Expensa
        WHERE Tipo=@Tipo AND NroExpensa=@NroExpensa;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage,16,1);
        RETURN;
    END CATCH
END
GO

