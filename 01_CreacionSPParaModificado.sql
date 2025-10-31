USE master

USE Com5600G07
GO

------------------------------------------ SCHEMA EXPENSAS -------------------------------------------
---------------------------------------- Para Tabla Expensa ----------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifExpensa
    @Tipo CHAR(1),
    @NroExpensa INT,
    @Mes TINYINT = NULL,
    @Anio SMALLINT = NULL,
    @FechaEmision DATE = NULL,
    @Vencimiento DATE = NULL,
    @Total DECIMAL(12,2) = NULL,
    @EstadoEnvio VARCHAR(20) = NULL,
    @MetodoEnvio VARCHAR(20) = NULL,
    @DestinoEnvio NVARCHAR(50) = NULL,
    @IdConsorcio INT = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        -- Validar existencia
        IF NOT EXISTS (
            SELECT 1
            FROM expensas.Expensa
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa
        )
        BEGIN
            PRINT('No existe una expensa con el tipo y número proporcionado.');
            RETURN;
        END

        -- Validar y modificar Mes
        IF @Mes IS NOT NULL
        BEGIN
            IF @Mes NOT BETWEEN 1 AND 12
            BEGIN
                PRINT('El mes debe estar entre 1 y 12.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Expensa
            SET Mes = @Mes
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Validar y modificar Año
        IF @Anio IS NOT NULL
        BEGIN
            IF @Anio < 2000
            BEGIN
                PRINT('El año no puede ser menor a 2000.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Expensa
            SET Anio = @Anio
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Validar y modificar Fechas
        IF @FechaEmision IS NOT NULL
        BEGIN
            IF @FechaEmision > GETDATE()
            BEGIN
                PRINT('La fecha de emisión no puede ser futura.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Expensa
            SET FechaEmision = @FechaEmision
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        IF @Vencimiento IS NOT NULL
        BEGIN
            DECLARE @FechaE DATE;
            SELECT @FechaE = FechaEmision FROM expensas.Expensa WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;

            IF @FechaE IS NULL SET @FechaE = ISNULL(@FechaEmision, GETDATE());

            IF @Vencimiento < @FechaE
            BEGIN
                PRINT('La fecha de vencimiento no puede ser anterior a la fecha de emisión.');
                RAISERROR('.', 16, 1);
            END

            UPDATE expensas.Expensa
            SET Vencimiento = @Vencimiento
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Validar y modificar Total
        IF @Total IS NOT NULL
        BEGIN
            IF @Total < 0
            BEGIN
                PRINT('El total no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Expensa
            SET Total = @Total
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Modificar Estado de Envío
        IF @EstadoEnvio IS NOT NULL AND @EstadoEnvio <> ''
        BEGIN
            UPDATE expensas.Expensa
            SET EstadoEnvio = TRIM(@EstadoEnvio)
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Modificar Método de Envío
        IF @MetodoEnvio IS NOT NULL AND @MetodoEnvio <> ''
        BEGIN
            UPDATE expensas.Expensa
            SET MetodoEnvio = TRIM(@MetodoEnvio)
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Modificar Destino de Envío
        IF @DestinoEnvio IS NOT NULL AND @DestinoEnvio <> ''
        BEGIN
            UPDATE expensas.Expensa
            SET DestinoEnvio = TRIM(@DestinoEnvio)
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        -- Modificar IdConsorcio
        IF @IdConsorcio IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.Consorcio WHERE IdConsorcio = @IdConsorcio)
            BEGIN
                PRINT('El IdConsorcio ingresado no existe.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Expensa
            SET IdConsorcio = @IdConsorcio
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa;
        END

        PRINT('Expensa actualizada correctamente.');
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

---------------------------------------- Para Tabla Prorrateo ----------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifProrrateo
    @Tipo CHAR(1),
    @NroExpensa INT,
    @IdUF INT,
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
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF
        )
        BEGIN
            PRINT('No existe un prorrateo con el Tipo, NroExpensa e IdUF proporcionados.');
            RETURN;
        END

        -- Validar referencia a Expensa
        IF NOT EXISTS (
            SELECT 1 FROM expensas.Expensa WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa
        )
        BEGIN
            PRINT('No existe la expensa asociada.');
            RAISERROR('.', 16, 1);
        END

        -- Validar referencia a Unidad Funcional
        IF NOT EXISTS (
            SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF
        )
        BEGIN
            PRINT('No existe la unidad funcional asociada.');
            RAISERROR('.', 16, 1);
        END

        ----------------------------
        -- Actualizaciones individuales
        ----------------------------

        -- SaldoAnterior
        IF @SaldoAnterior IS NOT NULL
        BEGIN
            IF @SaldoAnterior < 0
            BEGIN
                PRINT('El saldo anterior no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET SaldoAnterior = @SaldoAnterior
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- PagosRecibidos
        IF @PagosRecibidos IS NOT NULL
        BEGIN
            IF @PagosRecibidos < 0
            BEGIN
                PRINT('Los pagos recibidos no pueden ser negativos.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET PagosRecibidos = @PagosRecibidos
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- InteresMora
        IF @InteresMora IS NOT NULL
        BEGIN
            IF @InteresMora < 0
            BEGIN
                PRINT('El interés por mora no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET InteresMora = @InteresMora
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- ExpensaOrdinaria
        IF @ExpensaOrdinaria IS NOT NULL
        BEGIN
            IF @ExpensaOrdinaria < 0
            BEGIN
                PRINT('La expensa ordinaria no puede ser negativa.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET ExpensaOrdinaria = @ExpensaOrdinaria
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- ExpensaExtraordinaria
        IF @ExpensaExtraordinaria IS NOT NULL
        BEGIN
            IF @ExpensaExtraordinaria < 0
            BEGIN
                PRINT('La expensa extraordinaria no puede ser negativa.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET ExpensaExtraordinaria = @ExpensaExtraordinaria
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- Total
        IF @Total IS NOT NULL
        BEGIN
            IF @Total < 0
            BEGIN
                PRINT('El total no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET Total = @Total
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        -- Deuda
        IF @Deuda IS NOT NULL
        BEGIN
            IF @Deuda < 0
            BEGIN
                PRINT('La deuda no puede ser negativa.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.Prorrateo
            SET Deuda = @Deuda
            WHERE Tipo = @Tipo AND NroExpensa = @NroExpensa AND IdUF = @IdUF;
        END

        PRINT('Prorrateo actualizado correctamente.');
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

---------------------------------------- Para Tabla EstadoFinanciero ----------------------------------------
CREATE OR ALTER PROCEDURE expensas.sp_ModifEstadoFinanciero
    @IdFinanzas INT,
    @SaldoAnterior DECIMAL(12,2) = NULL,
    @Ingresos DECIMAL(12,2) = NULL,
    @Egresos DECIMAL(12,2) = NULL,
    @SaldoCierre DECIMAL(12,2) = NULL,
    @Tipo CHAR(1) = NULL,
    @NroExpensa INT = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        -- Validar existencia del registro
        IF NOT EXISTS (SELECT 1 FROM expensas.EstadoFinanciero WHERE IdFinanzas = @IdFinanzas)
        BEGIN
            PRINT('No existe un estado financiero con el IdFinanzas proporcionado.');
            RETURN;
        END

        ----------------------------
        -- Validaciones y updates
        ----------------------------

        -- SaldoAnterior
        IF @SaldoAnterior IS NOT NULL
        BEGIN
            IF @SaldoAnterior < 0
            BEGIN
                PRINT('El saldo anterior no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.EstadoFinanciero
            SET SaldoAnterior = @SaldoAnterior
            WHERE IdFinanzas = @IdFinanzas;
        END

        -- Ingresos
        IF @Ingresos IS NOT NULL
        BEGIN
            IF @Ingresos < 0
            BEGIN
                PRINT('Los ingresos no pueden ser negativos.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.EstadoFinanciero
            SET Ingresos = @Ingresos
            WHERE IdFinanzas = @IdFinanzas;
        END

        -- Egresos
        IF @Egresos IS NOT NULL
        BEGIN
            IF @Egresos < 0
            BEGIN
                PRINT('Los egresos no pueden ser negativos.');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.EstadoFinanciero
            SET Egresos = @Egresos
            WHERE IdFinanzas = @IdFinanzas;
        END

        -- SaldoCierre
        IF @SaldoCierre IS NOT NULL
        BEGIN
            UPDATE expensas.EstadoFinanciero
            SET SaldoCierre = @SaldoCierre
            WHERE IdFinanzas = @IdFinanzas;
        END

        -- Tipo (requiere validar con Expensa)
        IF @Tipo IS NOT NULL
        BEGIN
            IF @Tipo NOT IN ('O', 'E')
            BEGIN
                PRINT('El tipo debe ser O (Ordinaria) o E (Extraordinaria).');
                RAISERROR('.', 16, 1);
            END
            UPDATE expensas.EstadoFinanciero
            SET Tipo = @Tipo
            WHERE IdFinanzas = @IdFinanzas;
        END

        -- NroExpensa (y validar FK)
        IF @NroExpensa IS NOT NULL
        BEGIN
            DECLARE @TipoActual CHAR(1);
            SELECT @TipoActual = ISNULL(@Tipo, Tipo) 
            FROM expensas.EstadoFinanciero
            WHERE IdFinanzas = @IdFinanzas;

            IF NOT EXISTS (
                SELECT 1 FROM expensas.Expensa 
                WHERE Tipo = @TipoActual AND NroExpensa = @NroExpensa
            )
            BEGIN
                PRINT('No existe una expensa asociada con el tipo y número indicados.');
                RAISERROR('.', 16, 1);
            END

            UPDATE expensas.EstadoFinanciero
            SET NroExpensa = @NroExpensa
            WHERE IdFinanzas = @IdFinanzas;
        END

        PRINT('Estado financiero actualizado correctamente.');
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el estado financiero.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

------------------------------------------ SCHEMA EXTERNOS -------------------------------------------
---------------------------------------- Para Tabla Empleado ----------------------------------------
CREATE OR ALTER PROCEDURE Externos.sp_ModifEmpleado
    @IdEmpleado INT,
    @IdLimpieza INT,
    @IdGO INT = NULL,
    @Sueldo DECIMAL(10,2) = NULL,
    @nroFactura VARCHAR(15) = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        -- Validar existencia del empleado
        IF NOT EXISTS (
            SELECT 1 
            FROM Externos.Empleado 
            WHERE IdEmpleado = @IdEmpleado AND IdLimpieza = @IdLimpieza
        )
        BEGIN
            PRINT('No existe un empleado con el IdEmpleado e IdLimpieza proporcionados.');
            RETURN;
        END

        -- Modificar IdGO
        IF @IdGO IS NOT NULL
        BEGIN
            -- Validar FK en gastos.Limpieza
            IF NOT EXISTS (
                SELECT 1 
                FROM gastos.Limpieza 
                WHERE IdLimpieza = @IdLimpieza AND IdGO = @IdGO
            )
            BEGIN
                PRINT('El IdGO o IdLimpieza no corresponden a un registro válido en gastos.Limpieza.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Externos.Empleado
            SET IdGO = @IdGO
            WHERE IdEmpleado = @IdEmpleado AND IdLimpieza = @IdLimpieza;
        END

        -- Modificar Sueldo
        IF @Sueldo IS NOT NULL
        BEGIN
            IF @Sueldo < 0
            BEGIN
                PRINT('El sueldo no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Externos.Empleado
            SET Sueldo = @Sueldo
            WHERE IdEmpleado = @IdEmpleado AND IdLimpieza = @IdLimpieza;
        END

        -- Modificar nroFactura
        IF @nroFactura IS NOT NULL AND @nroFactura <> ''
        BEGIN
            SET @nroFactura = TRIM(@nroFactura);
            IF LEN(@nroFactura) > 15
            BEGIN
                PRINT('El número de factura excede el largo permitido (15 caracteres).');
                RAISERROR('.', 16, 1);
            END

            UPDATE Externos.Empleado
            SET nroFactura = @nroFactura
            WHERE IdEmpleado = @IdEmpleado AND IdLimpieza = @IdLimpieza;
        END

        PRINT('Empleado actualizado correctamente.');
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar el empleado.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

---------------------------------------- Para Tabla Empresa ----------------------------------------
CREATE OR ALTER PROCEDURE Externos.sp_ModifEmpresa
    @IdEmpresa INT,
    @IdLimpieza INT,
    @IdGO INT = NULL,
    @nroFactura VARCHAR(15) = NULL,
    @ImpFactura DECIMAL(12,2) = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        -- Validar existencia del registro
        IF NOT EXISTS (
            SELECT 1
            FROM Externos.Empresa
            WHERE IdEmpresa = @IdEmpresa AND IdLimpieza = @IdLimpieza
        )
        BEGIN
            PRINT('No existe una empresa con el IdEmpresa e IdLimpieza proporcionados.');
            RETURN;
        END

        ------------------------------------------------
        -- Modificar IdGO
        ------------------------------------------------
        IF @IdGO IS NOT NULL
        BEGIN
            -- Validar existencia de la FK en gastos.Limpieza
            IF NOT EXISTS (
                SELECT 1 
                FROM gastos.Limpieza
                WHERE IdLimpieza = @IdLimpieza AND IdGO = @IdGO
            )
            BEGIN
                PRINT('El IdGO o IdLimpieza no corresponden a un registro válido en gastos.Limpieza.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Externos.Empresa
            SET IdGO = @IdGO
            WHERE IdEmpresa = @IdEmpresa AND IdLimpieza = @IdLimpieza;
        END

        ------------------------------------------------
        -- Modificar nroFactura
        ------------------------------------------------
        IF @nroFactura IS NOT NULL AND @nroFactura <> ''
        BEGIN
            SET @nroFactura = TRIM(@nroFactura);
            IF LEN(@nroFactura) > 15
            BEGIN
                PRINT('El número de factura excede el largo máximo permitido (15 caracteres).');
                RAISERROR('.', 16, 1);
            END

            UPDATE Externos.Empresa
            SET nroFactura = @nroFactura
            WHERE IdEmpresa = @IdEmpresa AND IdLimpieza = @IdLimpieza;
        END

        ------------------------------------------------
        -- Modificar ImpFactura
        ------------------------------------------------
        IF @ImpFactura IS NOT NULL
        BEGIN
            IF @ImpFactura < 0
            BEGIN
                PRINT('El importe de factura no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Externos.Empresa
            SET ImpFactura = @ImpFactura
            WHERE IdEmpresa = @IdEmpresa AND IdLimpieza = @IdLimpieza;
        END

        PRINT('Empresa actualizada correctamente.');
    END TRY

    BEGIN CATCH
        IF ERROR_SEVERITY() > 10
        BEGIN
            RAISERROR('Ocurrió un error al modificar la empresa.', 16, 1);
            RETURN;
        END
    END CATCH
END
GO

------------------------------------------ SCHEMA PAGO -------------------------------------------
---------------------------------------- Para Tabla Pago ----------------------------------------
CREATE OR ALTER PROCEDURE Pago.sp_ModifPago
    @IdPago INT,
    @Fecha DATE = NULL,
    @Importe DECIMAL(12,2) = NULL,
    @CuentaOrigen CHAR(22) = NULL,
    @CuentaDestino CHAR(22) = NULL,
    @Estado VARCHAR(20) = NULL,
    @IdUF INT = NULL
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        ------------------------------------------------------------
        -- Validar existencia del pago
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Pago.Pago WHERE IdPago = @IdPago)
        BEGIN
            PRINT('No existe un pago con el IdPago proporcionado.');
            RETURN;
        END

        ------------------------------------------------------------
        -- Modificar Fecha
        ------------------------------------------------------------
        IF @Fecha IS NOT NULL
        BEGIN
            IF @Fecha > GETDATE()
            BEGIN
                PRINT('La fecha del pago no puede ser futura.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET Fecha = @Fecha
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar Importe
        ------------------------------------------------------------
        IF @Importe IS NOT NULL
        BEGIN
            IF @Importe < 0
            BEGIN
                PRINT('El importe no puede ser negativo.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET Importe = @Importe
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar CuentaOrigen
        ------------------------------------------------------------
        IF @CuentaOrigen IS NOT NULL AND @CuentaOrigen <> ''
        BEGIN
            SET @CuentaOrigen = TRIM(@CuentaOrigen);
            IF LEN(@CuentaOrigen) <> 22
            BEGIN
                PRINT('La cuenta origen debe tener exactamente 22 caracteres.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET CuentaOrigen = @CuentaOrigen
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar CuentaDestino
        ------------------------------------------------------------
        IF @CuentaDestino IS NOT NULL AND @CuentaDestino <> ''
        BEGIN
            SET @CuentaDestino = TRIM(@CuentaDestino);
            IF LEN(@CuentaDestino) <> 22
            BEGIN
                PRINT('La cuenta destino debe tener exactamente 22 caracteres.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET CuentaDestino = @CuentaDestino
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar Estado
        ------------------------------------------------------------
        IF @Estado IS NOT NULL AND @Estado <> ''
        BEGIN
            SET @Estado = TRIM(@Estado);
            IF @Estado NOT IN ('Pendiente', 'Confirmado', 'Rechazado')
            BEGIN
                PRINT('El estado debe ser Pendiente, Confirmado o Rechazado.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET Estado = @Estado
            WHERE IdPago = @IdPago;
        END

        ------------------------------------------------------------
        -- Modificar IdUF
        ------------------------------------------------------------
        IF @IdUF IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM consorcio.UnidadFuncional WHERE IdUF = @IdUF)
            BEGIN
                PRINT('El IdUF proporcionado no existe en consorcio.UnidadFuncional.');
                RAISERROR('.', 16, 1);
            END

            UPDATE Pago.Pago
            SET IdUF = @IdUF
            WHERE IdPago = @IdPago;
        END

        PRINT('Pago actualizado correctamente.');
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

