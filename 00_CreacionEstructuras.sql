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
--			CREACION DE LA BASE DE DATOS	   --
--											   --
-------------------------------------------------

-- Se verifica si la base de datos ya existe para evitar errores de ejecucion
IF DB_ID('Com5600G07') IS NULL
BEGIN
    PRINT 'Creando base de datos Com5600G07...';
    CREATE DATABASE Com5600G07
END
ELSE
BEGIN
    PRINT 'La base de datos Com5600G07 ya existe.';
END
GO

-- BORRAR BASE DE DATOS (No descomentar!)
--DROP DATABASE Com5600G07
--GO

USE Com5600G07
GO

-------------------------------------------------
--											   --
--			CREACION DE LOS ESQUEMAS	       --
--											   --
-------------------------------------------------

-- Esquema creado para las tablas de Consorcio, Unidad Funcional, Persona, Ocupacion, Cochera y Baulera.
CREATE SCHEMA consorcio
GO

-- Esquema creado para las tablas de Gasto Ordinario, Gasto Extraordinario, Gastos Generales, Seguros, Honorarios, Limpieza y Mantenimiento.
CREATE SCHEMA gastos
GO

-- Esquema creado para las tablas de Expensa, Prorrateo y Estado Financiero.
CREATE SCHEMA expensas
GO

-- Esquema creado para la tabla de Pago
CREATE SCHEMA Pago
GO

--Esquema creado para la tabla Empleado y Empresa
CREATE SCHEMA Externos
GO
-------------------------------------------------
--											   --
--			CREACION DE LAS TABLAS	           --
--											   --
-------------------------------------------------
-- Se crearan las tablas correspondientes a partir de las pautas consignadas en la Unidad 3 respecto a optimizacion de las mismas y sus tipos de datos.
-- 'U' filtra solo objetos de tipo tabla

IF OBJECT_ID('consorcio.Consorcio','U') IS NULL
BEGIN
    CREATE TABLE consorcio.Consorcio(
        IdConsorcio INT IDENTITY(1,1) PRIMARY KEY,
        NombreConsorcio VARCHAR(40) NOT NULL,
        Direccion NVARCHAR(100) NOT NULL,
        Superficie_Total DECIMAL(10,2) NOT NULL CHECK (Superficie_Total>0),
        MoraPrimerVTO DECIMAL(5,2) NOT NULL CHECK (MoraPrimerVTO>=0),
        MoraProxVTO DECIMAL(5,2) NOT NULL CHECK (MoraProxVTO>=0)
    );
END

IF OBJECT_ID('consorcio.UnidadFuncional','U') IS NULL
BEGIN
    CREATE TABLE consorcio.UnidadFuncional(
        IdUF INT IDENTITY(1,1) PRIMARY KEY,
        Piso NVARCHAR(10) NOT NULL,
        Depto NVARCHAR(10) NOT NULL,
        Superficie DECIMAL(6,2) NOT NULL CHECK(Superficie>0),
        Coeficiente DECIMAL(5,2) NOT NULL CHECK(Coeficiente>0 AND Coeficiente<=100),
        IdConsorcio INT NOT NULL,
        FOREIGN KEY(IdConsorcio) REFERENCES consorcio.Consorcio(IdConsorcio)
    );
END

IF OBJECT_ID('consorcio.Persona','U') IS NULL 
BEGIN
    CREATE TABLE consorcio.Persona(
        DNI VARCHAR(10) PRIMARY KEY,
        Nombre VARCHAR(30) NOT NULL,
        Apellido VARCHAR(30) NOT NULL,
        Email VARCHAR(40),
        Telefono VARCHAR(15),
        CVU CHAR(22),
        Fecha_Nacimiento DATE CHECK (Fecha_Nacimiento<=GETDATE()),
        IdUF INT NOT NULL,
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END

IF OBJECT_ID('consorcio.Ocupacion','U') IS NULL
BEGIN 
    CREATE TABLE consorcio.Ocupacion(
        Id_Ocupacion INT IDENTITY(1,1) PRIMARY KEY,
        Rol CHAR(11) NOT NULL CHECK (Rol IN ('Propietario','Inquilino')),
        FechaInicio DATE NOT NULL,
        FechaFin DATE NULL,
        IdUF INT NOT NULL,
        DNI VARCHAR(10) NOT NULL,
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF),
        FOREIGN KEY(DNI) REFERENCES consorcio.Persona(DNI),
        CONSTRAINT CK_Ocupacion_Fechas CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
    );
END

IF OBJECT_ID('consorcio.Baulera','U') IS NULL
BEGIN
    CREATE TABLE consorcio.Baulera(
        Id_Baulera INT IDENTITY(1,1) PRIMARY KEY,
        Tamanio DECIMAL(10,2) NOT NULL CHECK (Tamanio>0), --En metros^2
        IdUF INT NOT NULL,
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END

IF OBJECT_ID('consorcio.Cochera','U') IS NULL
BEGIN
    CREATE TABLE consorcio.Cochera(
        Id_Cochera INT IDENTITY(1,1) PRIMARY KEY,
        Tamanio DECIMAL(10,2) NOT NULL CHECK(Tamanio>0), --En metros^2
        IdUf INT NOT NULL,
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END

IF OBJECT_ID('expensas.Expensa','U') IS NULL
BEGIN
    CREATE TABLE expensas.Expensa (
        Tipo CHAR(1) NOT NULL CHECK(Tipo IN('O','E')), -- Ordinaria o Extraordinaria
        NroExpensa INT NOT NULL,
        Mes TINYINT NOT NULL CHECK (Mes BETWEEN 1 AND 12),
        Anio SMALLINT NOT NULL CHECK (Anio >= 2000),
        FechaEmision DATE NOT NULL, 
        Vencimiento DATE NOT NULL,
        Total DECIMAL(12,2) NOT NULL CHECK (Total >= 0),
        EstadoEnvio VARCHAR(20),
        MetodoEnvio VARCHAR(20),
        DestinoEnvio NVARCHAR(50),
        IdConsorcio INT NOT NULL,
        PRIMARY KEY(Tipo, NroExpensa),
        FOREIGN KEY(IdConsorcio) REFERENCES consorcio.Consorcio(IdConsorcio),
        CONSTRAINT CK_Expensa_Vencimiento CHECK (Vencimiento >= FechaEmision)
    );
END

IF OBJECT_ID('expensas.Prorrateo','U') IS NULL
BEGIN
    CREATE TABLE expensas.Prorrateo(
        IdProrrateo INT IDENTITY(1,1),
        Tipo CHAR(1) NOT NULL CHECK (Tipo IN ('O','E')),
        NroExpensa INT NOT NULL,
        IdUF INT NOT NULL,
        SaldoAnterior DECIMAL(12,2) NOT NULL CHECK (SaldoAnterior >= 0),
        PagosRecibidos DECIMAL(12,2) NOT NULL CHECK (PagosRecibidos >= 0),
        InteresMora DECIMAL(12,2) NOT NULL CHECK (InteresMora >= 0),
        ExpensaOrdinaria DECIMAL(12,2) CHECK (ExpensaOrdinaria >= 0),
        ExpensaExtraordinaria DECIMAL(12,2) CHECK (ExpensaExtraordinaria >= 0),
        Total DECIMAL(12,2) CHECK (Total >= 0),
        Deuda DECIMAL(12,2) CHECK (Deuda >= 0),
        PRIMARY KEY (Tipo, NroExpensa, IdUF),
        FOREIGN KEY (Tipo, NroExpensa) REFERENCES expensas.Expensa(Tipo, NroExpensa),
        FOREIGN KEY (IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END


IF OBJECT_ID('expensas.EstadoFinanciero','U') IS NULL
BEGIN
    CREATE TABLE expensas.EstadoFinanciero(
        IdFinanzas INT IDENTITY(1,1) PRIMARY KEY,
        SaldoAnterior DECIMAL(12,2) CHECK(SaldoAnterior >= 0),
        Ingresos DECIMAL(12,2) CHECK (Ingresos >= 0),
        Egresos DECIMAL(12,2) CHECK(Egresos >= 0),
        SaldoCierre DECIMAL(12,2),
        Tipo CHAR(1) NOT NULL CHECK (Tipo IN ('O','E')),
        NroExpensa INT NOT NULL,
        FOREIGN KEY (Tipo, NroExpensa) REFERENCES expensas.Expensa(Tipo, NroExpensa)
    );
END

IF OBJECT_ID('gastos.GastoExtraordinario','U') IS NULL
BEGIN
    CREATE TABLE gastos.GastoExtraordinario (
        IdGE INT IDENTITY(1,1),
        Tipo CHAR(1) NOT NULL CHECK (Tipo = 'E'), -- Solo extraordinaria
        nroExpensa INT NOT NULL,
        Detalle NVARCHAR(100) NOT NULL,
        ImporteTotal DECIMAL(12,2) NOT NULL CHECK (ImporteTotal > 0),
        Cuotas BIT NOT NULL, -- 1 = Sí, 0 = No
        ImporteCuota DECIMAL(12,2) CHECK (ImporteCuota >= 0),
        CuotaActual TINYINT CHECK (CuotaActual >= 1),
        TotalCuotas TINYINT,
        PRIMARY KEY (IdGE, Tipo, nroExpensa),
        FOREIGN KEY (Tipo, nroExpensa) REFERENCES expensas.Expensa(Tipo, NroExpensa),
        CONSTRAINT CK_GastoExtraordinario_Cuotas CHECK (TotalCuotas IS NULL OR TotalCuotas >= CuotaActual)
    );
END

IF OBJECT_ID('gastos.GastoOrdinario','U') IS NULL
BEGIN
    CREATE TABLE gastos.GastoOrdinario (
        IdGO INT IDENTITY(1,1),
        Tipo CHAR(1) NOT NULL CHECK(Tipo='O'), -- Puede ser Ordinaria
        Descripcion VARCHAR(50) NOT NULL,
        Importe DECIMAL(12,2) NOT NULL CHECK (Importe>=0),
        NroFactura VARCHAR(15) NOT NULL,
        nroExpensa INT NOT NULL,
        PRIMARY KEY(IdGO,Tipo),
        FOREIGN KEY(Tipo,nroExpensa) REFERENCES expensas.Expensa(Tipo, NroExpensa)
    );       
END

CREATE TABLE gastos.Generales (
    nroFactura VARCHAR(15),
    IdGO INT NOT NULL,
    Tipo CHAR(1) NOT NULL CHECK (Tipo = 'O'),
    TipoGasto VARCHAR(20) NOT NULL,
    NombreEmpresa VARCHAR(30) NOT NULL,
    Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),
    PRIMARY KEY (nroFactura, IdGO),
    FOREIGN KEY (IdGO, Tipo) REFERENCES gastos.GastoOrdinario(IdGO, Tipo)
);

IF OBJECT_ID ('gastos.Seguros','U') IS NULL
BEGIN
    CREATE TABLE gastos.Seguros (
        nroFactura VARCHAR(15),
        IdGO INT NOT NULL,
        Tipo CHAR(1) NOT NULL CHECK (Tipo = 'O'),
        NombreEmpresa VARCHAR(30) NOT NULL,
        Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),
        PRIMARY KEY (nroFactura, IdGO),
        FOREIGN KEY (IdGO, Tipo) REFERENCES gastos.GastoOrdinario(IdGO, Tipo)
    );
END

IF OBJECT_ID('gastos.Honorarios','U') IS NULL
BEGIN
    CREATE TABLE gastos.Honorarios (
        nroFactura VARCHAR(15),
        IdGO INT NOT NULL,
        Tipo CHAR(1) NOT NULL CHECK (Tipo = 'O'),
        Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),
        PRIMARY KEY (nroFactura, IdGO),
        FOREIGN KEY (IdGO, Tipo) REFERENCES gastos.GastoOrdinario(IdGO, Tipo)
    );
END

IF OBJECT_ID('gastos.Limpieza','U') IS NULL
BEGIN
    CREATE TABLE gastos.Limpieza (
        IdLimpieza INT IDENTITY(1,1),
        IdGO INT NOT NULL,
        Tipo CHAR(1) NOT NULL CHECK (Tipo = 'O'),
        Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),
        PRIMARY KEY (IdLimpieza, IdGO),
        FOREIGN KEY (IdGO, Tipo) REFERENCES gastos.GastoOrdinario(IdGO, Tipo)
    );
END

IF OBJECT_ID('gastos.Mantenimiento','U') IS NULL
BEGIN
    CREATE TABLE gastos.Mantenimiento (
        IdMantenimiento INT IDENTITY(1,1),
        IdGO INT NOT NULL,
        Tipo CHAR(1) NOT NULL CHECK (Tipo = 'O'),
        Importe DECIMAL(12,2) NOT NULL CHECK (Importe >= 0),
        CuentaBancaria CHAR(22) NOT NULL CHECK (CuentaBancaria NOT LIKE '%[^0-9]%'),
        PRIMARY KEY (IdMantenimiento, IdGO),
        FOREIGN KEY (IdGO, Tipo) REFERENCES gastos.GastoOrdinario(IdGO, Tipo)
    );
END

IF OBJECT_ID ('Externos.Empleado','U') IS NULL
BEGIN
    CREATE TABLE Externos.Empleado (
        IdEmpleado INT IDENTITY(1,1),
        IdLimpieza INT NOT NULL,
        IdGO INT NOT NULL,
        Sueldo DECIMAL(10,2) NOT NULL CHECK (Sueldo >= 0),
        nroFactura VARCHAR(15) NOT NULL,
        PRIMARY KEY (IdEmpleado, IdLimpieza),
        FOREIGN KEY (IdLimpieza, IdGO) REFERENCES gastos.Limpieza(IdLimpieza, IdGO)
    );
END

IF OBJECT_ID('Externos.Empresa','U') IS NULL
BEGIN
    CREATE TABLE Externos.Empresa (
        IdEmpresa INT IDENTITY(1,1),
        IdLimpieza INT NOT NULL,
        IdGO INT NOT NULL,
        nroFactura VARCHAR(15),
        ImpFactura DECIMAL(12,2) NOT NULL CHECK (ImpFactura >= 0),
        PRIMARY KEY (IdEmpresa, IdLimpieza),
        FOREIGN KEY (IdLimpieza, IdGO) REFERENCES gastos.Limpieza(IdLimpieza, IdGO)
    );
END

IF OBJECT_ID('Pago.Pago','U') IS NULL
BEGIN
    CREATE TABLE Pago.Pago(
        IdPago INT IDENTITY(1,1) PRIMARY KEY,
        Fecha DATE NOT NULL,
        Importe DECIMAL(12,2) NOT NULL CHECK(Importe>=0),
        CuentaOrigen CHAR(22) NOT NULL,
        CuentaDestino CHAR(22) NOT NULL,
        Estado VARCHAR(20) NULL CHECK (Estado IN ('Pendiente','Confirmado','Rechazado')),
        IdUF INT NOT NULL
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END
GO

