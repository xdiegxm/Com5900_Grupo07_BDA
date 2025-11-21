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
-------------------------------------------------
--											   --
--		        TABLA CONSORCIO                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_agrConsorcio
	@nombreconsorcio VARCHAR(40),
    @direccion NVARCHAR(100),
    @superficie_total DECIMAL(10,2),
    @cant_unidades_funcionales int,
    @moraprimervto DECIMAL(5,2),
    @moraproxvto DECIMAL(5,2)
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
            DECLARE @id INT;
            -- Validamos que no exista un consorcio con el mismo nombre y dirección
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
             
            -- Validaciones numéricas
            IF @superficie_total IS NULL OR @superficie_total <=0
            BEGIN
                PRINT('La superficie total debe ser mayor a 0.');
                RAISERROR('.',16,1);
            END

             IF @cant_unidades_funcionales IS NULL OR @cant_unidades_funcionales <=0
            BEGIN
                PRINT('La cantidad de unidades funcionales debe ser mayor a 0.');
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
    INSERT INTO consorcio.Consorcio (NombreConsorcio, Direccion, Superficie_Total, CantidadUnidadesFunc,MoraPrimerVTO, MoraProxVTO)
    VALUES (@NombreConsorcio, @Direccion, @Superficie_Total, @cant_unidades_funcionales, @MoraPrimerVTO, @MoraProxVTO);

    SET @id = SCOPE_IDENTITY();
    RETURN @id;
END 
GO

-------------------------------------------------
--											   --
--		     TABLA UNIDAD FUNCIONAL            --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.so_agrUnidadFuncional
    @Piso NVARCHAR(10),
    @Depto NVARCHAR(10),
    @Superficie DECIMAL(6,2),
    @Coeficiente DECIMAL(5,2),
    @IdConsorcio INT
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
            RETURN -1;
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

        --insercion de la nueva unidad funcional
        INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
        VALUES (@Piso, @Depto, @Superficie, @Coeficiente, @IdConsorcio);

        -- Retornar el ID creado
        DECLARE @NewIdUF INT = SCOPE_IDENTITY();
        RETURN @NewIdUF;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la unidad funcional.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA PERSONA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_agrPersona
    @DNI VARCHAR(10),
    @Nombre VARCHAR(30),
    @Apellido VARCHAR(30),
    @Email VARCHAR(40),
    @Telefono VARCHAR(15),
    @CVU CHAR(22),
    @idUF INT = NULL  -- Nuevo parámetro opcional
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

        -- Validación y limpieza de campos
        -- DNI
        IF @DNI = '' OR @DNI LIKE '%[^0-9]%' OR LEN(@DNI)>10
        BEGIN
            PRINT('El DNI no es valido.');
            RAISERROR('.',16,1);
        END
        SET @DNI=TRIM(@DNI);

        -- Nombre
        IF @Nombre='' OR @Nombre LIKE '%[^a-zA-Z ]%' OR LEN(@Nombre)>30
        BEGIN
            PRINT('Nombre ingresado no valido.');
            RAISERROR('.',16,1);
        END
        SET @Nombre = TRIM(@Nombre);

        -- Apellido
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
                PRINT('El correo electrónico no es valido.');
                RAISERROR('.', 16, 1);
            END
            SET @Email = TRIM(@Email);
        END

        -- Telefono
        IF @Telefono IS NOT NULL AND @Telefono <> ''
        BEGIN
            IF @Telefono LIKE '%[^0-9]%' OR LEN(@Telefono) > 15
            BEGIN
                PRINT('El telefono no es valido.');
                RAISERROR('.', 16, 1);
            END
            SET @Telefono = TRIM(@Telefono);
        END

        -- CVU
        IF @CVU IS NOT NULL AND @CVU <> ''
        BEGIN
            IF @CVU LIKE '%[^0-9]%' OR LEN(@CVU) <> 22
            BEGIN
                PRINT('El CVU debe tener exactamente 22 dígitos numericos.');
                RAISERROR('.', 16, 1);
            END
        END

        --IdUF
        IF @idUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @idUF)
            BEGIN
                PRINT('El IdUF proporcionado no existe en la tabla UnidadFuncional.');
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

    -- Inserción del registro 
    INSERT INTO consorcio.Persona (DNI, Nombre, Apellido, Email, Telefono, CVU, idUF)
    VALUES (@DNI, @Nombre, @Apellido, @Email, @Telefono, @CVU, @idUF);
    
    PRINT 'Persona insertada correctamente: ' + @DNI;
END 
GO

-------------------------------------------------
--											   --
--		        TABLA OCUPACION                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_agrOcupacion
    @Rol CHAR(11),
    @IdUF INT,  -- Cambié @iduf por @IdUF
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
        WHERE IdUF = @IdUF;  -- Usar @IdUF

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

        -- insertar ocupacion
        INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI)
        VALUES (@Rol, @IdUF, @DNI);  -- Usar @IdUF

        DECLARE @NewIdOcupacion INT = SCOPE_IDENTITY();
        RETURN @NewIdOcupacion;

    END TRY
     BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la ocupacion.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO
-------------------------------------------------
--											   --
--		        TABLA BAULERA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_agrBaulera
    @Tamanio DECIMAL(10,2),
    @IdUF INT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteUF INT;

        --validar que el IdUF exista
        SELECT @ExisteUF = IdUF
        FROM consorcio.UnidadFuncional
        WHERE IdUF = @IdUF;

        IF @ExisteUF IS NULL
        BEGIN
            PRINT('La unidad funcional indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        --validar tamanio
        IF @Tamanio IS NULL OR @Tamanio <= 0
        BEGIN
            PRINT('El tamanio debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

        --insertar baulera
        INSERT INTO consorcio.Baulera (Tamanio, IdUF)
        VALUES (@Tamanio, @IdUF);

        DECLARE @NewIdBaulera INT = SCOPE_IDENTITY();
        RETURN @NewIdBaulera;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la baulera.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA COCHERA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_agrCochera
    @Tamanio DECIMAL(10,2),
    @IdUF INT
AS
BEGIN
    BEGIN TRY
        DECLARE @IdCochera INT;

        --validacion de tamanio
        IF @Tamanio <= 0
        BEGIN
            PRINT('El tamanio de la cochera debe ser mayor a 0');
            RAISERROR('Tamanio invalido',16,1);
        END

        --verificacion de existencia de la Unidad Funcional
        IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
        BEGIN
            PRINT('La Unidad Funcional indicada no existe');
            RAISERROR('Unidad Funcional invalida',16,1);
        END

        --insercion
        INSERT INTO consorcio.Cochera (Tamanio, IdUF)
        VALUES (@Tamanio, @IdUF);
        
        SET @IdCochera = SCOPE_IDENTITY();
        RETURN @IdCochera;

    END TRY
    BEGIN CATCH
        PRINT('Ocurrio un error al registrar la cochera');
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage,16,1);
        RETURN -1;
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA EXPENSA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_agrExpensa
    @idConsorcio INT,
    @fechaGeneracion DATE,
    @fechaVto1 DATE = NULL,
    @fechaVto2 DATE = NULL,
    @montoTotal DECIMAL(10,2) = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteConsorcio INT;

        -- Validar que el consorcio exista
        SELECT @ExisteConsorcio = IdConsorcio
        FROM consorcio.Consorcio
        WHERE IdConsorcio = @idConsorcio;

        IF @ExisteConsorcio IS NULL
        BEGIN
            PRINT('El consorcio indicado no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de fechas
        IF @fechaGeneracion IS NULL OR @fechaGeneracion > GETDATE()
        BEGIN
            PRINT('La fecha de generación debe ser una fecha válida y no puede ser futura.');
            RAISERROR('.', 16, 1);
        END

        IF @fechaVto1 IS NOT NULL AND @fechaVto1 <= @fechaGeneracion
        BEGIN
            PRINT('La fecha del primer vencimiento debe ser posterior a la fecha de generación.');
            RAISERROR('.', 16, 1);
        END

        IF @fechaVto2 IS NOT NULL AND @fechaVto1 IS NOT NULL AND @fechaVto2 <= @fechaVto1
        BEGIN
            PRINT('La fecha del segundo vencimiento debe ser posterior al primer vencimiento.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de monto
        IF @montoTotal IS NOT NULL AND @montoTotal < 0
        BEGIN
            PRINT('El monto total no puede ser negativo.');
            RAISERROR('.', 16, 1);
        END

        -- Inserción de la expensa
        INSERT INTO expensas.Expensa (idConsorcio, fechaGeneracion, fechaVto1, fechaVto2, montoTotal)
        VALUES (@idConsorcio, @fechaGeneracion, @fechaVto1, @fechaVto2, @montoTotal);

        DECLARE @NroExpensa INT = SCOPE_IDENTITY();
        RETURN @NroExpensa;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al registrar la expensa.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA PRORRATEO                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_agrProrrateo
    @Porcentaje DECIMAL(10,2),
    @NroExpensa INT,
    @IdUF INT,
    @SaldoAnterior DECIMAL(12,2) = 0,
    @PagosRecibidos DECIMAL(12,2) = 0,
    @InteresMora DECIMAL(12,2) = 0,
    @ExpensaOrdinaria DECIMAL(12,2) = 0,
    @ExpensaExtraordinaria DECIMAL(12,2) = 0,
    @Total DECIMAL(12,2) = 0,
    @Deuda DECIMAL(12,2) = 0
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteExpensa INT;
        DECLARE @ExisteUF INT;
        DECLARE @IdExistente INT;

        -- Validar que la expensa exista
        SELECT @ExisteExpensa = nroExpensa
        FROM expensas.Expensa
        WHERE nroExpensa = @NroExpensa;

        IF @ExisteExpensa IS NULL
        BEGIN
            PRINT('La expensa indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validar que la UF exista
        SELECT @ExisteUF = IdUF
        FROM consorcio.UnidadFuncional
        WHERE IdUF = @IdUF;

        IF @ExisteUF IS NULL
        BEGIN
            PRINT('La unidad funcional indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validar que no exista ya un prorrateo para esta expensa y UF
        SELECT @IdExistente = IdProrrateo
        FROM expensas.Prorrateo
        WHERE NroExpensa = @NroExpensa AND IdUF = @IdUF;

        IF @IdExistente IS NOT NULL
        BEGIN
            PRINT('Ya existe un prorrateo para esta expensa y unidad funcional.');
            RAISERROR('.', 16, 1);
        END

        -- Validaciones de porcentaje
        IF @Porcentaje IS NULL OR @Porcentaje <= 0 OR @Porcentaje > 100
        BEGIN
            PRINT('El porcentaje debe estar entre 0 y 100.');
            RAISERROR('.', 16, 1);
        END

        -- Validaciones de montos (no negativos)
        IF @SaldoAnterior < 0 OR @PagosRecibidos < 0 OR @InteresMora < 0 OR 
           @ExpensaOrdinaria < 0 OR @ExpensaExtraordinaria < 0 OR @Total < 0 OR @Deuda < 0
        BEGIN
            PRINT('Todos los montos deben ser valores positivos o cero.');
            RAISERROR('.', 16, 1);
        END

        -- Inserción del prorrateo
        INSERT INTO expensas.Prorrateo (Porcentaje, NroExpensa, IdUF, SaldoAnterior, PagosRecibidos, 
                                       InteresMora, ExpensaOrdinaria, ExpensaExtraordinaria, Total, Deuda)
        VALUES (@Porcentaje, @NroExpensa, @IdUF, @SaldoAnterior, @PagosRecibidos, @InteresMora, 
                @ExpensaOrdinaria, @ExpensaExtraordinaria, @Total, @Deuda);

        DECLARE @IdProrrateo INT = SCOPE_IDENTITY();
        RETURN @IdProrrateo;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al registrar el prorrateo.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA PAGO                     --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE Pago.sp_agrPago
    @Fecha DATE,
    @Importe DECIMAL(12,2),
    @CuentaOrigen CHAR(22),
    @IdUF INT,
    @NroExpensa INT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteUF INT;
        DECLARE @ExisteExpensa INT;

        -- Validar que la UF exista
        SELECT @ExisteUF = IdUF
        FROM consorcio.UnidadFuncional
        WHERE IdUF = @IdUF;

        IF @ExisteUF IS NULL
        BEGIN
            PRINT('La unidad funcional indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validar que la expensa exista
        SELECT @ExisteExpensa = nroExpensa
        FROM expensas.Expensa
        WHERE nroExpensa = @NroExpensa;

        IF @ExisteExpensa IS NULL
        BEGIN
            PRINT('La expensa indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de fecha
        IF @Fecha IS NULL OR @Fecha > GETDATE()
        BEGIN
            PRINT('La fecha debe ser una fecha válida y no puede ser futura.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de importe
        IF @Importe IS NULL OR @Importe <= 0
        BEGIN
            PRINT('El importe debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de cuenta origen
        IF @CuentaOrigen = '' OR LEN(@CuentaOrigen) <> 22 OR @CuentaOrigen LIKE '%[^0-9]%'
        BEGIN
            PRINT('La cuenta de origen debe tener exactamente 22 dígitos numéricos.');
            RAISERROR('.', 16, 1);
        END
        SET @CuentaOrigen = TRIM(@CuentaOrigen);

        -- Inserción del pago
        INSERT INTO Pago.Pago (Fecha, Importe, CuentaOrigen, IdUF, NroExpensa)
        VALUES (@Fecha, @Importe, @CuentaOrigen, @IdUF, @NroExpensa);

        DECLARE @IdPago INT = SCOPE_IDENTITY();
        RETURN @IdPago;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al registrar el pago.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA GASTO                    --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_agrGasto
    @nroExpensa INT,
    @idConsorcio INT,
    @tipo VARCHAR(16),
    @descripcion VARCHAR(200) = NULL,
    @fechaEmision DATE = NULL,
    @importe DECIMAL(10,2) = 0
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteExpensa INT;
        DECLARE @ExisteConsorcio INT;

        -- Validar que la expensa exista
        SELECT @ExisteExpensa = nroExpensa
        FROM expensas.Expensa
        WHERE nroExpensa = @nroExpensa;

        IF @ExisteExpensa IS NULL
        BEGIN
            PRINT('La expensa indicada no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validar que el consorcio exista
        SELECT @ExisteConsorcio = IdConsorcio
        FROM consorcio.Consorcio
        WHERE IdConsorcio = @idConsorcio;

        IF @ExisteConsorcio IS NULL
        BEGIN
            PRINT('El consorcio indicado no existe.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de tipo
        IF @tipo NOT IN ('Ordinario', 'Extraordinario')
        BEGIN
            PRINT('El tipo debe ser "Ordinario" o "Extraordinario".');
            RAISERROR('.', 16, 1);
        END

        -- Validación de descripción
        IF @descripcion IS NOT NULL AND LEN(@descripcion) > 200
        BEGIN
            PRINT('La descripción no puede exceder los 200 caracteres.');
            RAISERROR('.', 16, 1);
        END
        SET @descripcion = TRIM(@descripcion);

        -- Validación de fecha
        IF @fechaEmision IS NULL
        BEGIN
            SET @fechaEmision = GETDATE();
        END
        ELSE IF @fechaEmision > GETDATE()
        BEGIN
            PRINT('La fecha de emisión no puede ser futura.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de importe
        IF @importe IS NULL OR @importe < 0
        BEGIN
            PRINT('El importe no puede ser negativo.');
            RAISERROR('.', 16, 1);
        END

        -- Inserción del gasto
        INSERT INTO gastos.Gasto (nroExpensa, idConsorcio, tipo, descripcion, fechaEmision, importe)
        VALUES (@nroExpensa, @idConsorcio, @tipo, @descripcion, @fechaEmision, @importe);

        DECLARE @IdGasto INT = SCOPE_IDENTITY();
        RETURN @IdGasto;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al registrar el gasto.', 16, 1);
            RETURN -1;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		   TABLA GASTO ORDINARIO               --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_agrGastoOrdinario
    @idGasto INT,
    @nombreProveedor VARCHAR(100) = NULL,
    @categoria VARCHAR(35) = NULL,
    @nroFactura VARCHAR(50) = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteGasto INT;
        DECLARE @TipoGasto VARCHAR(16);

        -- Validar que el gasto exista y sea de tipo Ordinario
        SELECT @ExisteGasto = idGasto, @TipoGasto = tipo
        FROM gastos.Gasto
        WHERE idGasto = @idGasto;

        IF @ExisteGasto IS NULL
        BEGIN
            PRINT('El gasto indicado no existe.');
            RAISERROR('.', 16, 1);
        END

        IF @TipoGasto <> 'Ordinario'
        BEGIN
            PRINT('El gasto debe ser de tipo Ordinario.');
            RAISERROR('.', 16, 1);
        END

        -- Validar que no exista ya un registro en Gasto_Ordinario para este idGasto
        IF EXISTS (SELECT 1 FROM gastos.Gasto_Ordinario WHERE idGasto = @idGasto)
        BEGIN
            PRINT('Ya existe un registro de gasto ordinario para este gasto.');
            RAISERROR('.', 16, 1);
        END

        -- Validaciones de longitud
        IF @nombreProveedor IS NOT NULL AND LEN(@nombreProveedor) > 100
        BEGIN
            PRINT('El nombre del proveedor no puede exceder los 100 caracteres.');
            RAISERROR('.', 16, 1);
        END
        SET @nombreProveedor = TRIM(@nombreProveedor);

        IF @categoria IS NOT NULL AND LEN(@categoria) > 35
        BEGIN
            PRINT('La categoría no puede exceder los 35 caracteres.');
            RAISERROR('.', 16, 1);
        END
        SET @categoria = TRIM(@categoria);

        IF @nroFactura IS NOT NULL AND LEN(@nroFactura) > 50
        BEGIN
            PRINT('El número de factura no puede exceder los 50 caracteres.');
            RAISERROR('.', 16, 1);
        END
        SET @nroFactura = TRIM(@nroFactura);

        -- Inserción del gasto ordinario
        INSERT INTO gastos.Gasto_Ordinario (idGasto, nombreProveedor, categoria, nroFactura)
        VALUES (@idGasto, @nombreProveedor, @categoria, @nroFactura);

        PRINT('Gasto ordinario registrado correctamente.');

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al registrar el gasto ordinario.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		 TABLA GASTO EXTRAORDINARIO            --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_agrGastoExtraordinario
    @idGasto INT,
    @cuotaActual TINYINT = NULL,
    @cantCuotas TINYINT = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @ExisteGasto INT;
        DECLARE @TipoGasto VARCHAR(16);

        -- Validar que el gasto exista y sea de tipo Extraordinario
        SELECT @ExisteGasto = idGasto, @TipoGasto = tipo
        FROM gastos.Gasto
        WHERE idGasto = @idGasto;

        IF @ExisteGasto IS NULL
        BEGIN
            PRINT('El gasto indicado no existe.');
            RAISERROR('.', 16, 1);
        END

        IF @TipoGasto <> 'Extraordinario'
        BEGIN
            PRINT('El gasto debe ser de tipo Extraordinario.');
            RAISERROR('.', 16, 1);
        END

        -- Validar que no exista ya un registro en Gasto_Extraordinario para este idGasto
        IF EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario WHERE idGasto = @idGasto)
        BEGIN
            PRINT('Ya existe un registro de gasto extraordinario para este gasto.');
            RAISERROR('.', 16, 1);
        END

        -- Validaciones de cuotas
        IF @cuotaActual IS NOT NULL AND (@cuotaActual <= 0 OR @cuotaActual > 255)
        BEGIN
            PRINT('La cuota actual debe ser un valor entre 1 y 255.');
            RAISERROR('.', 16, 1);
        END

        IF @cantCuotas IS NOT NULL AND (@cantCuotas <= 0 OR @cantCuotas > 255)
        BEGIN
            PRINT('La cantidad de cuotas debe ser un valor entre 1 y 255.');
            RAISERROR('.', 16, 1);
        END

        IF @cuotaActual IS NOT NULL AND @cantCuotas IS NOT NULL AND @cuotaActual > @cantCuotas
        BEGIN
            PRINT('La cuota actual no puede ser mayor que la cantidad total de cuotas.');
            RAISERROR('.', 16, 1);
        END

        -- Inserción del gasto extraordinario
        INSERT INTO gastos.Gasto_Extraordinario (idGasto, cuotaActual, cantCuotas)
        VALUES (@idGasto, @cuotaActual, @cantCuotas);

        PRINT('Gasto extraordinario registrado correctamente.');

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al registrar el gasto extraordinario.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO