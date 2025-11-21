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
-- Esquema creado para la tabla de reportes

IF SCHEMA_ID('report') IS NULL
BEGIN
	EXEC('CREATE SCHEMA report'); 
END

-- Esquema creado para las tablas de Consorcio, Unidad Funcional, Persona, Ocupacion, Cochera y Baulera.
IF SCHEMA_ID('consorcio') IS NULL
BEGIN
	EXEC('CREATE SCHEMA consorcio'); 
END
-- Esquema creado para las tablas de Gasto Ordinario, Gasto Extraordinario, Gastos Generales, Seguros, Honorarios, Limpieza y Mantenimiento.
IF SCHEMA_ID('gastos') IS NULL
BEGIN
	EXEC('CREATE SCHEMA gastos'); 
END
-- Esquema creado para las tablas de Expensa, Prorrateo y Estado Financiero.
IF SCHEMA_ID('expensas') IS NULL
BEGIN
	EXEC('CREATE SCHEMA expensas'); 
END
-- Esquema creado para la tabla de Pago
IF SCHEMA_ID('Pago') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Pago'); 
END
--Esquema creado para la tabla Empleado y Empresa
IF SCHEMA_ID('Externos') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Externos');
END

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
        CantidadUnidadesFunc int,
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
        idUF int,
        FOREIGN KEY(idUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END
    
IF OBJECT_ID('consorcio.Ocupacion','U') IS NULL
BEGIN 
    CREATE TABLE consorcio.Ocupacion(
        Id_Ocupacion INT IDENTITY(1,1) PRIMARY KEY,
        Rol CHAR(11) NOT NULL CHECK (Rol IN ('Propietario','Inquilino')),
        IdUF INT NOT NULL,
        DNI VARCHAR(10) NOT NULL,
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF),
        FOREIGN KEY(DNI) REFERENCES consorcio.Persona(DNI),
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
        nroExpensa INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
        idConsorcio INT NOT NULL,
        fechaGeneracion DATE NOT NULL,
        fechaVto1 DATE,
        fechaVto2 DATE,
        montoTotal DECIMAL(10,2),
        CONSTRAINT FK_Expensa_Consorcio FOREIGN KEY (idConsorcio) REFERENCES consorcio.Consorcio (IdConsorcio)
    );
END
GO

IF OBJECT_ID('expensas.Prorrateo','U') IS NULL
BEGIN
    CREATE TABLE expensas.Prorrateo(
        IdProrrateo INT IDENTITY(1,1),
        Porcentaje decimal(10,2),
        NroExpensa INT NOT NULL,
        IdUF INT NOT NULL,
        SaldoAnterior DECIMAL(12,2) CHECK (SaldoAnterior >= 0),
        PagosRecibidos DECIMAL(12,2) CHECK (PagosRecibidos >= 0),
        InteresMora DECIMAL(12,2) CHECK (InteresMora >= 0),
        ExpensaOrdinaria DECIMAL(12,2) CHECK (ExpensaOrdinaria >= 0),
        ExpensaExtraordinaria DECIMAL(12,2) CHECK (ExpensaExtraordinaria >= 0),
        Total DECIMAL(12,2) CHECK (Total >= 0),
        Deuda DECIMAL(12,2) CHECK (Deuda >= 0),
        PRIMARY KEY (IdProrrateo, IdUF),
        FOREIGN KEY (NroExpensa) REFERENCES expensas.Expensa(nroExpensa),
        FOREIGN KEY (IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END
GO

IF OBJECT_ID('Pago.Pago','U') IS NULL
BEGIN
    CREATE TABLE Pago.Pago(
        IdPago INT IDENTITY(1,1) PRIMARY KEY,
        Fecha DATE NOT NULL,
        Importe DECIMAL(12,2) NOT NULL CHECK(Importe>=0),
        CuentaOrigen CHAR(22) NOT NULL,
        IdUF INT NOT NULL,
		NroExpensa INT NOT NULL,
		FOREIGN KEY (NroExpensa) REFERENCES expensas.Expensa(nroExpensa),
        FOREIGN KEY(IdUF) REFERENCES consorcio.UnidadFuncional(IdUF)
    );
END
GO

IF OBJECT_ID('gastos.Gasto','U') IS NULL
BEGIN
    CREATE TABLE gastos.Gasto (
        idGasto INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
        nroExpensa INT NOT NULL,
        idConsorcio INT NOT NULL,
        tipo VARCHAR(16) CHECK (tipo IN ('Ordinario','Extraordinario')),
        descripcion VARCHAR(200),
        fechaEmision DATE DEFAULT GETDATE(),
        importe DECIMAL(10,2) DEFAULT 0,
        CONSTRAINT FK_Gasto_Consorcio
            FOREIGN KEY (idConsorcio) REFERENCES consorcio.Consorcio (IdConsorcio),
        CONSTRAINT FK_Gasto_Expensa
            FOREIGN KEY (nroExpensa) REFERENCES expensas.Expensa (nroExpensa)
    );
END

IF OBJECT_ID('gastos.Gasto_Ordinario','U') IS NULL
BEGIN
    CREATE TABLE gastos.Gasto_Ordinario (
        idGasto INT NOT NULL PRIMARY KEY,
        nombreProveedor VARCHAR(100),
        categoria VARCHAR(35),
        nroFactura VARCHAR(50),
        CONSTRAINT FK_Ordinario_Gasto
            FOREIGN KEY (idGasto) REFERENCES gastos.Gasto (idGasto)
    );
END

IF OBJECT_ID('gastos.Gasto_Extraordinario','U') IS NULL
BEGIN
    CREATE TABLE gastos.Gasto_Extraordinario (
        idGasto INT NOT null primary key,
        cuotaActual TINYINT,
        cantCuotas TINYINT,
        CONSTRAINT FK_Extraordinario_Gasto2
            FOREIGN KEY (idGasto) REFERENCES gastos.Gasto (idGasto)
    );
END


IF OBJECT_ID('report.logsReportes','U') IS NULL
BEGIN
    CREATE TABLE report.logsReportes(
            IdLog INT IDENTITY(1,1) PRIMARY KEY,
            Fecha DATETIME2(3) NOT NULL CONSTRAINT DF_logsReportes_fecha DEFAULT SYSUTCDATETIME(),
            SP SYSNAME NULL,
            Tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('INFO', 'WARN', 'ERROR')), -- INFO | WARN | ERROR
            Mensaje NVARCHAR(4000) NULL,
            RutaArchivo NVARCHAR(4000) NULL, -- archivo origen (ej. Excel/CSV)
    );
END
GO
