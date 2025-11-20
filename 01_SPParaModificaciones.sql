-------------------------------------------------
--											   --
--		        TABLA PERSONA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_ModifPersona
    @DNI VARCHAR(10),
    @Nombre VARCHAR(30) = NULL,
    @Apellido VARCHAR(30) = NULL,
    @Email VARCHAR(40) = NULL,
    @Telefono VARCHAR(15) = NULL,
    @CVU CHAR(22) = NULL,
    @idUF INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia de la persona
        IF NOT EXISTS (SELECT 1 FROM consorcio.Persona WHERE DNI = @DNI)
        BEGIN
            PRINT('No existe una persona con el DNI proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @Nombre IS NOT NULL
        BEGIN
            IF @Nombre = '' OR @Nombre LIKE '%[^a-zA-Z ]%' OR LEN(@Nombre) > 30
            BEGIN
                PRINT('Nombre ingresado no válido.');
                RAISERROR('.', 16, 1);
            END
            SET @Nombre = TRIM(@Nombre);
        END

        IF @Apellido IS NOT NULL
        BEGIN
            IF @Apellido = '' OR @Apellido LIKE '%[^a-zA-Z ]%' OR LEN(@Apellido) > 30
            BEGIN
                PRINT('Apellido ingresado no válido.');
                RAISERROR('.', 16, 1);
            END
            SET @Apellido = TRIM(@Apellido);
        END

        IF @Email IS NOT NULL AND @Email <> ''
        BEGIN
            IF @Email NOT LIKE '%@%.%' OR LEN(@Email) > 40
            BEGIN
                PRINT('El correo electrónico no es válido.');
                RAISERROR('.', 16, 1);
            END
            SET @Email = TRIM(@Email);
        END

        IF @Telefono IS NOT NULL AND @Telefono <> ''
        BEGIN
            IF @Telefono LIKE '%[^0-9]%' OR LEN(@Telefono) > 15
            BEGIN
                PRINT('El teléfono no es válido.');
                RAISERROR('.', 16, 1);
            END
            SET @Telefono = TRIM(@Telefono);
        END

        IF @CVU IS NOT NULL AND @CVU <> ''
        BEGIN
            IF @CVU LIKE '%[^0-9]%' OR LEN(@CVU) <> 22
            BEGIN
                PRINT('El CVU debe tener exactamente 22 dígitos numéricos.');
                RAISERROR('.', 16, 1);
            END
        END

        IF @idUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @idUF)
            BEGIN
                PRINT('El IdUF proporcionado no existe en la tabla UnidadFuncional.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Actualización
        UPDATE consorcio.Persona
        SET 
            Nombre = COALESCE(@Nombre, Nombre),
            Apellido = COALESCE(@Apellido, Apellido),
            Email = COALESCE(@Email, Email),
            Telefono = COALESCE(@Telefono, Telefono),
            CVU = COALESCE(@CVU, CVU),
            idUF = COALESCE(@idUF, idUF)
        WHERE 
            DNI = @DNI;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('La persona existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Persona con DNI ' + @DNI + ' actualizada correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la persona.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA GASTO                    --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_ModifGasto
    @IdGasto INT,
    @nroExpensa INT = NULL,
    @idConsorcio INT = NULL,
    @tipo VARCHAR(16) = NULL,
    @descripcion VARCHAR(200) = NULL,
    @fechaEmision DATE = NULL,
    @importe DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia del gasto
        IF NOT EXISTS (SELECT 1 FROM gastos.Gasto WHERE idGasto = @IdGasto)
        BEGIN
            PRINT('No existe un gasto con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de referencias
        IF @nroExpensa IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE nroExpensa = @nroExpensa)
            BEGIN
                PRINT('La expensa indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        IF @idConsorcio IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @idConsorcio)
            BEGIN
                PRINT('El consorcio indicado no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Validación de tipo
        IF @tipo IS NOT NULL
        BEGIN
            IF @tipo NOT IN ('Ordinario', 'Extraordinario')
            BEGIN
                PRINT('El tipo debe ser "Ordinario" o "Extraordinario".');
                RAISERROR('.', 16, 1);
            END
        END

        -- Validación de descripción
        IF @descripcion IS NOT NULL AND LEN(@descripcion) > 200
        BEGIN
            PRINT('La descripción no puede exceder los 200 caracteres.');
            RAISERROR('.', 16, 1);
        END
        SET @descripcion = TRIM(@descripcion);

        -- Validación de fecha
        IF @fechaEmision IS NOT NULL AND @fechaEmision > GETDATE()
        BEGIN
            PRINT('La fecha de emisión no puede ser futura.');
            RAISERROR('.', 16, 1);
        END

        -- Validación de importe
        IF @importe IS NOT NULL AND @importe < 0
        BEGIN
            PRINT('El importe no puede ser negativo.');
            RAISERROR('.', 16, 1);
        END

        -- Actualización
        UPDATE gastos.Gasto
        SET 
            nroExpensa = COALESCE(@nroExpensa, nroExpensa),
            idConsorcio = COALESCE(@idConsorcio, idConsorcio),
            tipo = COALESCE(@tipo, tipo),
            descripcion = COALESCE(@descripcion, descripcion),
            fechaEmision = COALESCE(@fechaEmision, fechaEmision),
            importe = COALESCE(@importe, importe)
        WHERE 
            idGasto = @IdGasto;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('El gasto existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Gasto con ID ' + CAST(@IdGasto AS VARCHAR) + ' actualizado correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el gasto.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA PRORRATEO                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifProrrateo
    @IdProrrateo INT,
    @IdUF INT,
    @Porcentaje DECIMAL(10,2) = NULL,
    @SaldoAnterior DECIMAL(12,2) = NULL,
    @PagosRecibidos DECIMAL(12,2) = NULL,
    @InteresMora DECIMAL(12,2) = NULL,
    @ExpensaOrdinaria DECIMAL(12,2) = NULL,
    @ExpensaExtraordinaria DECIMAL(12,2) = NULL,
    @Total DECIMAL(12,2) = NULL,
    @Deuda DECIMAL(12,2) = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        -- Validar existencia del prorrateo
        IF NOT EXISTS (
            SELECT 1 
            FROM expensas.Prorrateo
            WHERE IdProrrateo = @IdProrrateo AND IdUF = @IdUF
        )
        BEGIN
            PRINT('No existe un prorrateo con el IdProrrateo e IdUF proporcionados.');
            RETURN;
        END

        -- Validación de porcentaje
        IF @Porcentaje IS NOT NULL
        BEGIN
            IF @Porcentaje <= 0 OR @Porcentaje > 100
            BEGIN
                PRINT('El porcentaje debe estar entre 0 y 100.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Validaciones de montos (no negativos)
        IF @SaldoAnterior IS NOT NULL AND @SaldoAnterior < 0 OR 
           @PagosRecibidos IS NOT NULL AND @PagosRecibidos < 0 OR 
           @InteresMora IS NOT NULL AND @InteresMora < 0 OR 
           @ExpensaOrdinaria IS NOT NULL AND @ExpensaOrdinaria < 0 OR 
           @ExpensaExtraordinaria IS NOT NULL AND @ExpensaExtraordinaria < 0 OR 
           @Total IS NOT NULL AND @Total < 0 OR 
           @Deuda IS NOT NULL AND @Deuda < 0
        BEGIN
            PRINT('Todos los montos deben ser valores positivos o cero.');
            RAISERROR('.', 16, 1);
        END

        -- Actualización
        UPDATE expensas.Prorrateo
        SET 
            Porcentaje = COALESCE(@Porcentaje, Porcentaje),
            SaldoAnterior = COALESCE(@SaldoAnterior, SaldoAnterior),
            PagosRecibidos = COALESCE(@PagosRecibidos, PagosRecibidos),
            InteresMora = COALESCE(@InteresMora, InteresMora),
            ExpensaOrdinaria = COALESCE(@ExpensaOrdinaria, ExpensaOrdinaria),
            ExpensaExtraordinaria = COALESCE(@ExpensaExtraordinaria, ExpensaExtraordinaria),
            Total = COALESCE(@Total, Total),
            Deuda = COALESCE(@Deuda, Deuda)
        WHERE 
            IdProrrateo = @IdProrrateo AND IdUF = @IdUF;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('El prorrateo existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Prorrateo actualizado correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el prorrateo.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA CONSORCIO                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_ModifConsorcio
    @IdConsorcio INT,
    @NombreConsorcio VARCHAR(40) = NULL,
    @Direccion NVARCHAR(100) = NULL,
    @CantidadUnidadesFunc INT = NULL,
    @Superficie_Total DECIMAL(10,2) = NULL,
    @MoraPrimerVTO DECIMAL(5,2) = NULL,
    @MoraProxVTO DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia del consorcio
        IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
        BEGIN
            PRINT('No existe un consorcio con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @NombreConsorcio IS NOT NULL
        BEGIN
            IF @NombreConsorcio = '' OR LEN(@NombreConsorcio) > 40
            BEGIN 
                PRINT('El nombre del consorcio no es válido.');
                RAISERROR('.', 16, 1);
            END
            SET @NombreConsorcio = TRIM(@NombreConsorcio);
        END

        IF @Direccion IS NOT NULL
        BEGIN
            IF @Direccion = '' OR LEN(@Direccion) > 100
            BEGIN
                PRINT('La dirección no es válida.');
                RAISERROR('.', 16, 1);
            END
            SET @Direccion = TRIM(@Direccion);
        END

        IF @CantidadUnidadesFunc IS NOT NULL AND @CantidadUnidadesFunc <= 0
        BEGIN
            PRINT('La cantidad de unidades funcionales debe ser mayor a 0.');
            RAISERROR('.', 16, 1);
        END

        IF @Superficie_Total IS NOT NULL AND @Superficie_Total <= 0
        BEGIN
            PRINT('La superficie total debe ser mayor a 0.');
            RAISERROR('.', 16, 1);
        END

        IF @MoraPrimerVTO IS NOT NULL AND @MoraPrimerVTO < 0
        BEGIN
            PRINT('La mora del primer vencimiento no puede ser negativa.');
            RAISERROR('.', 16, 1);
        END

        IF @MoraProxVTO IS NOT NULL AND @MoraProxVTO < 0
        BEGIN
            PRINT('La mora del próximo vencimiento no puede ser negativa.');
            RAISERROR('.', 16, 1);
        END

        -- Actualización
        UPDATE consorcio.Consorcio
        SET 
            NombreConsorcio = COALESCE(@NombreConsorcio, NombreConsorcio),
            Direccion = COALESCE(@Direccion, Direccion),
            CantidadUnidadesFunc = COALESCE(@CantidadUnidadesFunc, CantidadUnidadesFunc),
            Superficie_Total = COALESCE(@Superficie_Total, Superficie_Total),
            MoraPrimerVTO = COALESCE(@MoraPrimerVTO, MoraPrimerVTO),
            MoraProxVTO = COALESCE(@MoraProxVTO, MoraProxVTO)
        WHERE 
            IdConsorcio = @IdConsorcio;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('El consorcio existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Consorcio con ID ' + CAST(@IdConsorcio AS VARCHAR) + ' actualizado correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el consorcio.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		   TABLA UNIDAD FUNCIONAL              --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_ModifUnidadFuncional
    @IdUF INT,
    @Piso NVARCHAR(10) = NULL,
    @Depto NVARCHAR(10) = NULL,
    @Superficie DECIMAL(6,2) = NULL,
    @Coeficiente DECIMAL(5,2) = NULL,
    @IdConsorcio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia de la UF
        IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
        BEGIN
            PRINT('No existe una unidad funcional con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @Piso IS NOT NULL
        BEGIN
            IF @Piso = '' OR LEN(@Piso) > 10
            BEGIN
                PRINT('El piso no es válido.');
                RAISERROR('.', 16, 1);
            END
            SET @Piso = TRIM(@Piso);
        END

        IF @Depto IS NOT NULL
        BEGIN
            IF @Depto = '' OR LEN(@Depto) > 10
            BEGIN
                PRINT('El departamento no es válido.');
                RAISERROR('.', 16, 1);
            END
            SET @Depto = TRIM(@Depto);
        END

        IF @Superficie IS NOT NULL AND @Superficie <= 0
        BEGIN
            PRINT('La superficie debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

        IF @Coeficiente IS NOT NULL AND (@Coeficiente <= 0 OR @Coeficiente > 100)
        BEGIN
            PRINT('El coeficiente debe ser mayor a 0 y menor o igual a 100.');
            RAISERROR('.', 16, 1);
        END

        IF @IdConsorcio IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
            BEGIN
                PRINT('El consorcio indicado no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Actualización
        UPDATE consorcio.UnidadFuncional
        SET 
            Piso = COALESCE(@Piso, Piso),
            Depto = COALESCE(@Depto, Depto),
            Superficie = COALESCE(@Superficie, Superficie),
            Coeficiente = COALESCE(@Coeficiente, Coeficiente),
            IdConsorcio = COALESCE(@IdConsorcio, IdConsorcio)
        WHERE 
            IdUF = @IdUF;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('La unidad funcional existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Unidad funcional con ID ' + CAST(@IdUF AS VARCHAR) + ' actualizada correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la unidad funcional.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA OCUPACION                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_ModifOcupacion
    @Id_Ocupacion INT,
    @Rol CHAR(11) = NULL,
    @IdUF INT = NULL,
    @DNI VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia de la ocupación
        IF NOT EXISTS (SELECT 1 FROM consorcio.Ocupacion WHERE Id_Ocupacion = @Id_Ocupacion)
        BEGIN
            PRINT('No existe una ocupación con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @Rol IS NOT NULL
        BEGIN
            IF @Rol NOT IN ('Propietario', 'Inquilino')
            BEGIN
                PRINT('El rol debe ser "Propietario" o "Inquilino".');
                RAISERROR('.', 16, 1);
            END
        END

        IF @IdUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
            BEGIN
                PRINT('La unidad funcional indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        IF @DNI IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.Persona WHERE DNI = @DNI)
            BEGIN
                PRINT('La persona indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Actualización
        UPDATE consorcio.Ocupacion
        SET 
            Rol = COALESCE(@Rol, Rol),
            IdUF = COALESCE(@IdUF, IdUF),
            DNI = COALESCE(@DNI, DNI)
        WHERE 
            Id_Ocupacion = @Id_Ocupacion;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('La ocupación existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Ocupación con ID ' + CAST(@Id_Ocupacion AS VARCHAR) + ' actualizada correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la ocupación.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA BAULERA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_ModifBaulera
    @Id_Baulera INT,
    @Tamanio DECIMAL(10,2) = NULL,
    @IdUF INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia de la baulera
        IF NOT EXISTS (SELECT 1 FROM consorcio.Baulera WHERE Id_Baulera = @Id_Baulera)
        BEGIN
            PRINT('No existe una baulera con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @Tamanio IS NOT NULL AND @Tamanio <= 0
        BEGIN
            PRINT('El tamaño debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

        IF @IdUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
            BEGIN
                PRINT('La unidad funcional indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Actualización
        UPDATE consorcio.Baulera
        SET 
            Tamanio = COALESCE(@Tamanio, Tamanio),
            IdUF = COALESCE(@IdUF, IdUF)
        WHERE 
            Id_Baulera = @Id_Baulera;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('La baulera existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Baulera con ID ' + CAST(@Id_Baulera AS VARCHAR) + ' actualizada correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la baulera.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA COCHERA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_ModifCochera
    @Id_Cochera INT,
    @Tamanio DECIMAL(10,2) = NULL,
    @IdUF INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia de la cochera
        IF NOT EXISTS (SELECT 1 FROM consorcio.Cochera WHERE Id_Cochera = @Id_Cochera)
        BEGIN
            PRINT('No existe una cochera con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @Tamanio IS NOT NULL AND @Tamanio <= 0
        BEGIN
            PRINT('El tamaño debe ser mayor a cero.');
            RAISERROR('.', 16, 1);
        END

        IF @IdUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
            BEGIN
                PRINT('La unidad funcional indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Actualización
        UPDATE consorcio.Cochera
        SET 
            Tamanio = COALESCE(@Tamanio, Tamanio),
            IdUF = COALESCE(@IdUF, IdUF)
        WHERE 
            Id_Cochera = @Id_Cochera;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('La cochera existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Cochera con ID ' + CAST(@Id_Cochera AS VARCHAR) + ' actualizada correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la cochera.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA EXPENSA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifExpensa
    @NroExpensa INT,
    @IdConsorcio INT = NULL,
    @FechaGeneracion DATE = NULL,
    @FechaVto1 DATE = NULL,
    @FechaVto2 DATE = NULL,
    @MontoTotal DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia de la expensa
        IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE nroExpensa = @NroExpensa)
        BEGIN
            PRINT('No existe una expensa con el número proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @IdConsorcio IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
            BEGIN
                PRINT('El consorcio indicado no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        IF @FechaGeneracion IS NOT NULL AND @FechaGeneracion > GETDATE()
        BEGIN
            PRINT('La fecha de generación no puede ser futura.');
            RAISERROR('.', 16, 1);
        END

        IF @MontoTotal IS NOT NULL AND @MontoTotal < 0
        BEGIN
            PRINT('El monto total no puede ser negativo.');
            RAISERROR('.', 16, 1);
        END

        -- Validaciones de fechas de vencimiento
        DECLARE @FechaG DATE;
        SELECT @FechaG = ISNULL(@FechaGeneracion, fechaGeneracion) FROM expensas.Expensa WHERE nroExpensa = @NroExpensa;

        IF @FechaVto1 IS NOT NULL AND @FechaVto1 < @FechaG
        BEGIN
            PRINT('La fecha de vencimiento 1 no puede ser anterior a la fecha de generación.');
            RAISERROR('.', 16, 1);
        END

        IF @FechaVto2 IS NOT NULL AND @FechaVto2 < @FechaG
        BEGIN
            PRINT('La fecha de vencimiento 2 no puede ser anterior a la fecha de generación.');
            RAISERROR('.', 16, 1);
        END

        -- Actualización
        UPDATE expensas.Expensa
        SET 
            idConsorcio = COALESCE(@IdConsorcio, idConsorcio),
            fechaGeneracion = COALESCE(@FechaGeneracion, fechaGeneracion),
            fechaVto1 = COALESCE(@FechaVto1, fechaVto1),
            fechaVto2 = COALESCE(@FechaVto2, fechaVto2),
            montoTotal = COALESCE(@MontoTotal, montoTotal)
        WHERE 
            nroExpensa = @NroExpensa;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('La expensa existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Expensa con número ' + CAST(@NroExpensa AS VARCHAR) + ' actualizada correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la expensa.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA PAGO                     --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE Pago.sp_ModifPago
    @IdPago INT,
    @Fecha DATE = NULL,
    @Importe DECIMAL(12,2) = NULL,
    @CuentaOrigen CHAR(22) = NULL,
    @IdUF INT = NULL,
    @NroExpensa INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia del pago
        IF NOT EXISTS (SELECT 1 FROM Pago.Pago WHERE IdPago = @IdPago)
        BEGIN
            PRINT('No existe un pago con el ID proporcionado.');
            RETURN;
        END

        -- Validaciones de campos
        IF @Fecha IS NOT NULL AND @Fecha > GETDATE()
        BEGIN
            PRINT('La fecha del pago no puede ser futura.');
            RAISERROR('.', 16, 1);
        END

        IF @Importe IS NOT NULL AND @Importe < 0
        BEGIN
            PRINT('El importe no puede ser negativo.');
            RAISERROR('.', 16, 1);
        END

        IF @CuentaOrigen IS NOT NULL
        BEGIN
            SET @CuentaOrigen = TRIM(@CuentaOrigen);
            IF LEN(@CuentaOrigen) <> 22 OR @CuentaOrigen LIKE '%[^0-9]%'
            BEGIN
                PRINT('La cuenta origen debe tener exactamente 22 dígitos numéricos.');
                RAISERROR('.', 16, 1);
            END
        END

        IF @IdUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
            BEGIN
                PRINT('La unidad funcional indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        IF @NroExpensa IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE nroExpensa = @NroExpensa)
            BEGIN
                PRINT('La expensa indicada no existe.');
                RAISERROR('.', 16, 1);
            END
        END

        -- Actualización
        UPDATE Pago.Pago
        SET 
            Fecha = COALESCE(@Fecha, Fecha),
            Importe = COALESCE(@Importe, Importe),
            CuentaOrigen = COALESCE(@CuentaOrigen, CuentaOrigen),
            IdUF = COALESCE(@IdUF, IdUF),
            NroExpensa = COALESCE(@NroExpensa, NroExpensa)
        WHERE 
            IdPago = @IdPago;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('El pago existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Pago con ID ' + CAST(@IdPago AS VARCHAR) + ' actualizado correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el pago.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		   TABLA GASTO ORDINARIO               --
--											   --
-------------------------------------------------

CREATE OR ALTER PROCEDURE gastos.sp_modifgastoordinario
    @idGasto INT, 
    @nombreProveedor varchar(100) = null,
    @categoria varchar(35) = null,
    @nrofactura varchar(50) = null
as
begin
    set nocount on;

    begin try
        --valido pk
        if not exists (select 1 from gastos.Gasto_Ordinario where idGasto = @idGasto)
        begin
            print 'Error: No existe un Gasto Ordinario con el ID proporcionado';
            return;
        end

        --valido que el gasto exista en la tabla principal y sea de tipo Ordinario
        if not exists (
            select 1 
            from gastos.Gasto g 
            where g.idGasto = @idGasto 
            and g.tipo = 'Ordinario'
        )
        begin
            print 'Error: El ID proporcionado no corresponde a un Gasto Ordinario válido';
            return;
        end

        update gastos.Gasto_Ordinario
        set
            nombreProveedor = coalesce(@nombreProveedor, nombreProveedor),
            categoria = coalesce(@categoria, categoria),
            nroFactura = coalesce(@nrofactura, nroFactura)
        where
            idGasto = @idGasto;
            
        if @@rowcount > 0
        begin
            print 'Gasto Ordinario con ID ' + cast(@idGasto as varchar) + ' actualizado correctamente.';
        end
        else
        begin
            print 'Gasto Ordinario existe, pero no se proporcionaron valores nuevos para actualizar.';
        end

    end try
    begin catch
        print 'Error: no se pudo modificar la tabla de gastos ordinarios';
        print ERROR_MESSAGE();
    end catch
end
go
-------------------------------------------------
--											   --
--		 TABLA GASTO EXTRAORDINARIO            --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_ModifGastoExtraordinario
    @idGasto INT,
    @cuotaActual TINYINT = NULL,
    @cantCuotas TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar existencia del gasto extraordinario
        IF NOT EXISTS (SELECT 1 FROM gastos.Gasto_Extraordinario WHERE idGasto = @idGasto)
        BEGIN
            PRINT('No existe un gasto extraordinario con el ID proporcionado.');
            RETURN;
        END

        -- Validar que el gasto principal sea de tipo Extraordinario
        IF NOT EXISTS (SELECT 1 FROM gastos.Gasto WHERE idGasto = @idGasto AND tipo = 'Extraordinario')
        BEGIN
            PRINT('El ID proporcionado no corresponde a un gasto extraordinario válido.');
            RAISERROR('.', 16, 1);
        END

        -- Validaciones de campos
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

        -- Actualización
        UPDATE gastos.Gasto_Extraordinario
        SET 
            cuotaActual = COALESCE(@cuotaActual, cuotaActual),
            cantCuotas = COALESCE(@cantCuotas, cantCuotas)
        WHERE 
            idGasto = @idGasto;

        IF @@ROWCOUNT = 0
        BEGIN
            PRINT('El gasto extraordinario existe, pero no se proporcionaron valores nuevos para actualizar.');
        END
        ELSE
        BEGIN
            PRINT('Gasto extraordinario con ID ' + CAST(@idGasto AS VARCHAR) + ' actualizado correctamente.');
        END

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el gasto extraordinario.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO