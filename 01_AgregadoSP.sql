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
    INSERT INTO consorcio.UnidadFuncional (Piso, Depto, Superficie, Coeficiente, IdConsorcio)
    VALUES (@Piso, @Depto, @Superficie, @Coeficiente, @IdConsorcio);
END
GO

-------------------------------------------------
--											   --
--		        TABLA OCUPACION                --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_agrOcupacion
    @Rol CHAR(11),
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
    END TRY
     BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la ocupacion.', 16, 1);
            RETURN;
        END
    END CATCH

    -- insertar ocupacion
    INSERT INTO consorcio.Ocupacion (Rol, IdUF, DNI)
    VALUES (@Rol, @IdUF, @DNI);
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

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrio un error al registrar la baulera.', 16, 1);
            RETURN;
        END
    END CATCH

    --insertar baulera
    INSERT INTO consorcio.Baulera (Tamanio, IdUF)
    VALUES (@Tamanio, @IdUF);

    PRINT('Baulera registrada correctamente.');
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
        RETURN;
    END CATCH
END
GO

-------------------------------------------------
--											   --
--		        TABLA EXPENSA                  --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_agrExpensa
    @Tipo CHAR(1),
    @NroExpensa INT,
    @Mes TINYINT,
    @Anio SMALLINT,
    @FechaGeneracion DATE,
    @Total DECIMAL(12,2),
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
            RAISERROR('Año invalido',16,1);
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

        --retornar datos insertados
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

-------------------------------------------------
--											   --
--		       TABLA PRORRATEO                 --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_agrProrrateo
    @Tipo CHAR(1),
    @NroExpensa INT,
    @IdUF INT,
    @SaldoAnterior DECIMAL(12,2),
    @PagosRecibidos DECIMAL(12,2),
    @InteresMora DECIMAL(12,2),
    @ExpensaOrdinaria DECIMAL(12,2) = NULL,
    @ExpensaExtraordinaria DECIMAL(12,2) = NULL,
    @Total DECIMAL(12,2),
    @Deuda DECIMAL(12,2)
AS
BEGIN 
    BEGIN TRY
        SET NOCOUNT ON;
        DECLARE @IdProrrateo INT;

        IF @Tipo NOT IN ('O','E')
        BEGIN 
            PRINT('Tipo debe ser O (Ordinaria) o E (Extraordinaria)');
            RAISERROR('.',16,1);
        END

        IF @NroExpensa IS NULL OR @NroExpensa <= 0
        BEGIN
            PRINT('Número de expensa invalido.');
            RAISERROR('.',16,1);
        END

        IF @IdUF IS NULL OR @IdUF <= 0
        BEGIN
            PRINT('El IdUF no es valido.');
            RAISERROR('.',16,1);
        END

        IF @SaldoAnterior IS NULL OR @SaldoAnterior < 0
        BEGIN
            PRINT('Saldo anterior invalido.');
            RAISERROR('.',16,1);
        END

        IF @PagosRecibidos IS NULL OR @PagosRecibidos < 0
        BEGIN
            PRINT('Pagos recibidos invalidos.');
            RAISERROR('.',16,1);
        END

        IF @InteresMora IS NULL OR @InteresMora < 0
        BEGIN
            PRINT('Interés por mora invalido.');
            RAISERROR('.',16,1);
        END

        IF @ExpensaOrdinaria IS NOT NULL AND @ExpensaOrdinaria < 0
        BEGIN
            PRINT('El valor de Expensa Ordinaria no puede ser negativo.');
            RAISERROR('.',16,1);
        END

        IF @ExpensaExtraordinaria IS NOT NULL AND @ExpensaExtraordinaria < 0
        BEGIN
            PRINT('El valor de Expensa Extraordinaria no puede ser negativo.');
            RAISERROR('.',16,1);
        END

        IF @Total IS NULL OR @Total < 0
        BEGIN
            PRINT('El total no puede ser negativo.');
            RAISERROR('.',16,1);
        END

        IF @Deuda IS NULL OR @Deuda < 0
        BEGIN
            PRINT('La deuda no puede ser negativa.');
            RAISERROR('.',16,1);
        END

        IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa)
        BEGIN
            PRINT('No existe una Expensa asociada con ese Tipo y NroExpensa.');
            RAISERROR('.',16,1);
        END

        IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
        BEGIN
            PRINT('La Unidad Funcional indicada no existe.');
            RAISERROR('.',16,1);
        END

        IF EXISTS (SELECT 1 FROM expensas.Prorrateo WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF)
        BEGIN
            PRINT('Ya existe un prorrateo con ese Tipo, NroExpensa e IdUF.');
            RAISERROR('.',16,1);
        END

        -- insercion
        INSERT INTO expensas.Prorrateo (Tipo, NroExpensa, IdUF, SaldoAnterior, PagosRecibidos, InteresMora,ExpensaOrdinaria, ExpensaExtraordinaria, Total, Deuda)
        VALUES (@Tipo, @NroExpensa, @IdUF, @SaldoAnterior, @PagosRecibidos, @InteresMora, @ExpensaOrdinaria, @ExpensaExtraordinaria, @Total, @Deuda);
        
        SET @IdProrrateo = SCOPE_IDENTITY();
        RETURN @IdProrrateo;
    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            PRINT('Ocurrió un error al registrar el prorrateo.');
            RAISERROR(@ErrorMessage,16,1);
            RETURN;
        END
    END CATCH
END;
GO

-------------------------------------------------
--											   --
--		    TABLA ESTADO FINANCIERO            --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_agrEstadoFinanciero
    @SaldoAnterior DECIMAL(12,2),
    @pagoEnTermino DECIMAL(12,2),
    @pagoAdeudado DECIMAL(12,2),
    @pagoAdelantado DECIMAL(12,2),
    @SaldoCierre DECIMAL(12,2),
    @Egresos DECIMAl(12,2),
    @idConsorcio int
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @IdFinanzas INT;


        IF @pagoAdelantado IS NULL OR @pagoAdelantado < 0
        BEGIN
            PRINT('El pago adelntado no puede ser negativo ni nulo.');
            RAISERROR('.',16,1);
        END
        IF @pagoAdeudado IS NULL OR @pagoAdeudado < 0
        BEGIN
            PRINT('El pago adeudado no puede ser negativo ni nulo.');
            RAISERROR('.',16,1);
        END
        IF @pagoEnTermino IS NULL OR @pagoEnTermino < 0
        BEGIN
            PRINT('El pago en Termino no puede ser negativo ni nulo.');
            RAISERROR('.',16,1);
        END

        IF @Ingresos IS NULL OR @Ingresos < 0
        BEGIN
            PRINT('Los ingresos no pueden ser negativos ni nulos.');
            RAISERROR('.',16,1);
        END

        IF @Egresos IS NULL OR @Egresos < 0
        BEGIN
            PRINT('Los egresos no pueden ser negativos ni nulos.');
            RAISERROR('.',16,1);
        END
        if not exists(select 1 from consorcio.Consorcio where @idConsorcio=IdConsorcio)
        begin
            print('Consorcio Invalido');
            RAISERROR('.',16,1);
        end
        --evitar duplicados
        IF EXISTS (
            SELECT 1 FROM expensas.EstadoFinanciero 
            WHERE idConsorcio=@idConsorcio
        )
        BEGIN
            PRINT('Ya existe un Estado Financiero para esta consorcio.');
            RAISERROR('.',16,1);
        END

        --insercion
        INSERT INTO expensas.EstadoFinanciero (SaldoAnterior,pagoEnTermino,pagoAdeudado,pagoAdelantado,Egresos,SaldoCierre,idConsorcio)
        VALUES (@SaldoAnterior, @pagoEnTermino,@pagoAdeudado,@pagoAdelantado,@Egresos,@SaldoCierre,@idConsorcio);

        SET @IdFinanzas = SCOPE_IDENTITY();
        RETURN @IdFinanzas;

    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            PRINT('Ocurrio un error al registrar el estado financiero.');
            RAISERROR(@ErrorMessage,16,1);
            RETURN;
        END
    END CATCH
END;
GO

-------------------------------------------------
--											   --
--		   TABLA GASTO EXTRAORDINARIO          --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_agrGastoExtraordinario
    @Tipo CHAR(1),
    @NroExpensa INT,
    @Detalle NVARCHAR(100),
    @ImporteTotal DECIMAL(12,2),
    @Cuotas BIT,
    @ImporteCuota DECIMAL(12,2) = NULL,
    @CuotaActual TINYINT = NULL,
    @TotalCuotas TINYINT = NULL
AS 
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        DECLARE @IdGE INT;

        --validacion de tipo
        IF @Tipo IS NULL OR @Tipo <> 'E'
        BEGIN
            PRINT('El tipo debe ser "E" para gasto extraordinario.');
            RAISERROR('.',16,1);
        END

        --validaciones de nroexpensa
        IF @NroExpensa IS NULL OR @NroExpensa <=0
            BEGIN
            PRINT('El número de expensa debe ser mayor a 0.');
            RAISERROR('.',16,1);
        END

        --validacion de detalle 
        IF @Detalle IS NULL OR LTRIM(RTRIM(@Detalle)) = '' OR LEN(@Detalle) > 100
        BEGIN
            PRINT('El detalle no es valido (vacio o supera los 100 caracteres).');
            RAISERROR('.',16,1);
        END
        SET @Detalle = TRIM(@Detalle);

        --validacion de importe
        IF @ImporteTotal IS NULL OR @ImporteTotal <= 0
        BEGIN
            PRINT('El importe total debe ser mayor que 0.');
            RAISERROR('.',16,1);
        END

        --validacion de cuotas
        IF @Cuotas NOT IN (0,1)
        BEGIN
            PRINT('El valor de "Cuotas" debe ser 0 o 1.');
            RAISERROR('.',16,1);
        END

        IF @Cuotas = 1
        BEGIN
            IF @ImporteCuota IS NULL OR @ImporteCuota <= 0
            BEGIN
                PRINT('Debe especificar un importe de cuota valido.');
                RAISERROR('.',16,1);
            END

            IF @CuotaActual IS NULL OR @CuotaActual < 1
            BEGIN
                PRINT('Debe indicar una cuota actual valida (>=1).');
                RAISERROR('.',16,1);
            END

            IF @TotalCuotas IS NULL OR @TotalCuotas < @CuotaActual
            BEGIN
                PRINT('El total de cuotas debe ser mayor o igual a la cuota actual.');
                RAISERROR('.',16,1);
            END
        END
        ELSE
        BEGIN
            -- Si no tiene cuotas, los campos relacionados deben ser NULL
            SET @ImporteCuota = NULL;
            SET @CuotaActual = NULL;
            SET @TotalCuotas = NULL;
        END
    END TRY
    
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Error al registrar el gasto extraordinario.',16,1);
            RETURN;
        END
    END CATCH

    --insercion
    INSERT INTO gastos.GastoExtraordinario (Tipo, nroExpensa, Detalle, ImporteTotal, Cuotas, ImporteCuota, CuotaActual, TotalCuotas)
    VALUES (@Tipo, @NroExpensa, @Detalle, @ImporteTotal, @Cuotas, @ImporteCuota, @CuotaActual, @TotalCuotas);

    SET @IdGE=SCOPE_IDENTITY();
    RETURN @IdGE;
END
GO

-------------------------------------------------
--											   --
--		     TABLA GASTO ORDINARIO             --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_agrGastoOrdinario
    @Tipo CHAR(1),
    @Descripcion VARCHAR(50),
    @Importe DECIMAL(12,2),
    @NroFactura VARCHAR(15),
    @NroExpensa INT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @IdGO INT;

        --validaciones
         IF @Tipo IS NULL OR @Tipo <> 'O'
        BEGIN
            PRINT('El tipo debe ser "O" para gasto ordinario.');
            RAISERROR('.',16,1);
        END

        IF @Descripcion IS NULL OR LTRIM(RTRIM(@Descripcion)) = '' OR LEN(@Descripcion) > 50
        BEGIN
            PRINT('La descripcion no es valida (vacia o supera los 50 caracteres).');
            RAISERROR('.',16,1);
        END
        SET @Descripcion = TRIM(@Descripcion);

        IF @Importe IS NULL OR @Importe < 0
        BEGIN
            PRINT('El importe debe ser mayor o igual a 0.');
            RAISERROR('.',16,1);
        END

        IF @NroFactura IS NULL OR LTRIM(RTRIM(@NroFactura)) = '' OR LEN(@NroFactura) > 15
        BEGIN
            PRINT('El numero de factura no es valido.');
            RAISERROR('.',16,1);
        END
        SET @NroFactura = TRIM(@NroFactura);

        IF @NroExpensa IS NULL OR @NroExpensa <= 0
        BEGIN
            PRINT('El numero de expensa no es valido.');
            RAISERROR('.',16,1);
        END

        --verificar existencia de la expensa
        IF NOT EXISTS (SELECT 1 FROM expensas.Expensa WHERE Tipo='O' AND NroExpensa=@NroExpensa)
        BEGIN
            PRINT('La expensa ordinaria indicada no existe.');
            RAISERROR('.',16,1);
        END
    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Error al registrar el gasto ordinario.',16,1);
            RETURN;
        END
    END CATCH

    --insercion
    INSERT INTO gastos.GastoOrdinario (Tipo, Descripcion, Importe, NroFactura, nroExpensa)
    VALUES (@Tipo, @Descripcion, @Importe, @NroFactura, @NroExpensa);
    SET @IdGO = SCOPE_IDENTITY();
    RETURN @IdGO;
END 
GO

-------------------------------------------------
--											   --
--		       TABLA GENERALES                 --
--											   --
-------------------------------------------------
CREATE OR ALTER PROCEDURE gastos.sp_agrGenerales
    @NroFactura VARCHAR(15),
    @IdGO INT,
    @Tipo CHAR(1),
    @TipoGasto VARCHAR(20),
    @NombreEmpresa VARCHAR(30),
    @Importe DECIMAL(12,2)
AS
BEGIN 
    BEGIN TRY
       SET NOCOUNT ON;

        --validaciones
        IF @Tipo IS NULL OR @Tipo <> 'O'
        BEGIN
            PRINT('El tipo debe ser "O" para gastos generales.');
            RAISERROR('.',16,1);
        END 

        IF @NroFactura IS NULL OR LTRIM(RTRIM(@NroFactura)) = '' OR LEN(@NroFactura) > 15
        BEGIN
            PRINT('Numero de factura no valido.');
            RAISERROR('.',16,1);
        END
        SET @NroFactura = TRIM(@NroFactura);

        IF @TipoGasto IS NULL OR LTRIM(RTRIM(@TipoGasto)) = '' OR LEN(@TipoGasto) > 20
        BEGIN
            PRINT('Tipo de gasto no valido.');
            RAISERROR('.',16,1);
        END
        SET @TipoGasto = TRIM(@TipoGasto);

        IF @NombreEmpresa IS NULL OR LTRIM(RTRIM(@NombreEmpresa)) = '' OR LEN(@NombreEmpresa) > 30
        BEGIN
            PRINT('Nombre de empresa no valido.');
            RAISERROR('.',16,1);
        END
        SET @NombreEmpresa = TRIM(@NombreEmpresa);

        IF @Importe IS NULL OR @Importe < 0
        BEGIN
            PRINT('Importe debe ser mayor o igual a 0.');
            RAISERROR('.',16,1);
        END

        IF NOT EXISTS (SELECT 1 FROM gastos.GastoOrdinario WHERE IdGO=@IdGO AND Tipo='O')
        BEGIN
            PRINT('El gasto ordinario padre indicado no existe.');
            RAISERROR('.',16,1);
        END
    END TRY
    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Error al registrar el gasto general.',16,1);
            RETURN;
        END
    END CATCH
    
    INSERT INTO gastos.Generales (nroFactura, IdGO, Tipo, TipoGasto, NombreEmpresa, Importe)
    VALUES (@NroFactura, @IdGO, @Tipo, @TipoGasto, @NombreEmpresa, @Importe);
    SELECT nroFactura, IdGO, Tipo, TipoGasto, NombreEmpresa, Importe
    FROM gastos.Generales
    WHERE nroFactura=@NroFactura AND IdGO=@IdGO;
END
GO

