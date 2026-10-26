/* =====================================================================
   TPI Base de Datos II - Equipo 03
   Sistema de gestión de personas vetadas y control de acceso a tiendas
   ---------------------------------------------------------------------
   01 - Creación de la base de datos, tablas y restricciones
   Motor: SQL Server 2017 o superior
   Orden de ejecución: 01 -> 02 -> 03 -> 04 -> 05 -> 06
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- necesario por el índice filtrado de USUARIO_TIENDA
GO

USE master;
GO

IF DB_ID('BD2_TPI_G03') IS NOT NULL
BEGIN
    ALTER DATABASE BD2_TPI_G03 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BD2_TPI_G03;
END
GO

CREATE DATABASE BD2_TPI_G03;
GO

USE BD2_TPI_G03;
GO

/* ---------------------------------------------------------------------
   ROL: perfiles de los usuarios del sistema de gestión
   --------------------------------------------------------------------- */
CREATE TABLE ROL (
    id_rol       INT IDENTITY(1,1) NOT NULL,
    nombre       NVARCHAR(50)      NOT NULL,
    descripcion  NVARCHAR(500)     NULL,
    CONSTRAINT PK_ROL PRIMARY KEY (id_rol),
    CONSTRAINT UQ_ROL_nombre UNIQUE (nombre)
);
GO

/* ---------------------------------------------------------------------
   USUARIO: personal autorizado que usa la web de gestión
   --------------------------------------------------------------------- */
CREATE TABLE USUARIO (
    id_usuario       INT IDENTITY(1,1) NOT NULL,
    id_rol           INT               NOT NULL,
    nombre           NVARCHAR(100)     NOT NULL,
    email            VARCHAR(254)      NOT NULL,
    hash_contrasena  VARCHAR(255)      NOT NULL,
    CONSTRAINT PK_USUARIO PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_USUARIO_email UNIQUE (email),
    CONSTRAINT FK_USUARIO_ROL FOREIGN KEY (id_rol) REFERENCES ROL (id_rol),
    CONSTRAINT CK_USUARIO_email CHECK (email LIKE '%_@_%._%')
);
GO

/* ---------------------------------------------------------------------
   TIENDA
   --------------------------------------------------------------------- */
CREATE TABLE TIENDA (
    id_tienda  INT IDENTITY(1,1) NOT NULL,
    nombre     NVARCHAR(100)     NOT NULL,
    direccion  NVARCHAR(250)     NOT NULL,
    CONSTRAINT PK_TIENDA PRIMARY KEY (id_tienda),
    CONSTRAINT UQ_TIENDA_nombre UNIQUE (nombre)
);
GO

/* ---------------------------------------------------------------------
   USUARIO_TIENDA: asignación de usuarios a tiendas, con historial.
   Corrección de la 1ra entrega: la PK deja de ser (id_usuario, id_tienda)
   para poder asignar dos veces al mismo usuario a la misma tienda en
   períodos distintos. fecha_hasta NULL = asignación vigente.
   El índice único filtrado impide dos asignaciones vigentes iguales.
   --------------------------------------------------------------------- */
CREATE TABLE USUARIO_TIENDA (
    id_usuario_tienda  INT IDENTITY(1,1) NOT NULL,
    id_usuario         INT               NOT NULL,
    id_tienda          INT               NOT NULL,
    fecha_desde        DATE              NOT NULL,
    fecha_hasta        DATE              NULL,
    CONSTRAINT PK_USUARIO_TIENDA PRIMARY KEY (id_usuario_tienda),
    CONSTRAINT FK_USUARIO_TIENDA_USUARIO FOREIGN KEY (id_usuario) REFERENCES USUARIO (id_usuario),
    CONSTRAINT FK_USUARIO_TIENDA_TIENDA  FOREIGN KEY (id_tienda)  REFERENCES TIENDA (id_tienda),
    CONSTRAINT CK_USUARIO_TIENDA_fechas CHECK (fecha_hasta IS NULL OR fecha_hasta >= fecha_desde)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_USUARIO_TIENDA_vigente
    ON USUARIO_TIENDA (id_usuario, id_tienda)
    WHERE fecha_hasta IS NULL;
GO

/* ---------------------------------------------------------------------
   TIPO_INCIDENTE
   --------------------------------------------------------------------- */
CREATE TABLE TIPO_INCIDENTE (
    id_tipo_incidente  INT IDENTITY(1,1) NOT NULL,
    nombre             NVARCHAR(100)     NOT NULL,
    descripcion        NVARCHAR(500)     NULL,
    CONSTRAINT PK_TIPO_INCIDENTE PRIMARY KEY (id_tipo_incidente),
    CONSTRAINT UQ_TIPO_INCIDENTE_nombre UNIQUE (nombre)
);
GO

/* ---------------------------------------------------------------------
   PERSONA_VETADA: base central de personas con al menos un incidente.
   referencia_facial guarda el vector/plantilla que usa el motor de
   inferencia para reconocer a la persona.
   --------------------------------------------------------------------- */
CREATE TABLE PERSONA_VETADA (
    id_persona         INT IDENTITY(1,1) NOT NULL,
    nombre             NVARCHAR(100)     NOT NULL,
    apellido           NVARCHAR(100)     NOT NULL,
    documento          VARCHAR(20)       NOT NULL,
    referencia_facial  VARBINARY(MAX)    NOT NULL,
    fecha_alta         DATETIME2(0)      NOT NULL CONSTRAINT DF_PERSONA_VETADA_fecha_alta DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_PERSONA_VETADA PRIMARY KEY (id_persona),
    CONSTRAINT UQ_PERSONA_VETADA_documento UNIQUE (documento),
    CONSTRAINT CK_PERSONA_VETADA_documento CHECK (LEN(documento) >= 6)
);
GO

/* ---------------------------------------------------------------------
   INCIDENTE: hecho ocurrido en una tienda, registrado por un usuario
   --------------------------------------------------------------------- */
CREATE TABLE INCIDENTE (
    id_incidente       INT IDENTITY(1,1) NOT NULL,
    id_tienda          INT               NOT NULL,
    id_tipo_incidente  INT               NOT NULL,
    id_usuario         INT               NOT NULL,
    fecha_hora         DATETIME2(0)      NOT NULL,
    descripcion        NVARCHAR(2000)    NOT NULL,
    CONSTRAINT PK_INCIDENTE PRIMARY KEY (id_incidente),
    CONSTRAINT FK_INCIDENTE_TIENDA         FOREIGN KEY (id_tienda)         REFERENCES TIENDA (id_tienda),
    CONSTRAINT FK_INCIDENTE_TIPO_INCIDENTE FOREIGN KEY (id_tipo_incidente) REFERENCES TIPO_INCIDENTE (id_tipo_incidente),
    CONSTRAINT FK_INCIDENTE_USUARIO        FOREIGN KEY (id_usuario)        REFERENCES USUARIO (id_usuario),
    CONSTRAINT CK_INCIDENTE_fecha CHECK (fecha_hora <= SYSDATETIME())
);
GO

CREATE NONCLUSTERED INDEX IX_INCIDENTE_tienda_fecha ON INCIDENTE (id_tienda, fecha_hora);
GO

/* ---------------------------------------------------------------------
   PERSONA_INCIDENTE: un incidente puede involucrar a varias personas y
   una persona puede tener varios incidentes (N a N)
   --------------------------------------------------------------------- */
CREATE TABLE PERSONA_INCIDENTE (
    id_persona    INT NOT NULL,
    id_incidente  INT NOT NULL,
    CONSTRAINT PK_PERSONA_INCIDENTE PRIMARY KEY (id_persona, id_incidente),
    CONSTRAINT FK_PERSONA_INCIDENTE_PERSONA   FOREIGN KEY (id_persona)   REFERENCES PERSONA_VETADA (id_persona),
    CONSTRAINT FK_PERSONA_INCIDENTE_INCIDENTE FOREIGN KEY (id_incidente) REFERENCES INCIDENTE (id_incidente)
);
GO

/* ---------------------------------------------------------------------
   VETO
   Corrección de la 1ra entrega:
   - id_tienda NULL  -> veto para TODAS las tiendas de la empresa.
     id_tienda con valor -> veto solo para esa tienda.
   - id_incidente (NULL permitido) indica qué incidente originó el veto.
   - fecha_fin NULL -> veto por tiempo indeterminado.
   - estado: ACTIVO o LEVANTADO (baja lógica; los vetos no se borran).
     Un veto ACTIVO con fecha_fin anterior a hoy se considera vencido.
   --------------------------------------------------------------------- */
CREATE TABLE VETO (
    id_veto       INT IDENTITY(1,1) NOT NULL,
    id_persona    INT               NOT NULL,
    id_usuario    INT               NOT NULL,
    id_incidente  INT               NULL,
    id_tienda     INT               NULL,
    fecha_inicio  DATE              NOT NULL,
    fecha_fin     DATE              NULL,
    estado        VARCHAR(20)       NOT NULL CONSTRAINT DF_VETO_estado DEFAULT ('ACTIVO'),
    motivo        NVARCHAR(500)     NOT NULL,
    CONSTRAINT PK_VETO PRIMARY KEY (id_veto),
    CONSTRAINT FK_VETO_PERSONA   FOREIGN KEY (id_persona)   REFERENCES PERSONA_VETADA (id_persona),
    CONSTRAINT FK_VETO_USUARIO   FOREIGN KEY (id_usuario)   REFERENCES USUARIO (id_usuario),
    CONSTRAINT FK_VETO_INCIDENTE FOREIGN KEY (id_incidente) REFERENCES INCIDENTE (id_incidente),
    CONSTRAINT FK_VETO_TIENDA    FOREIGN KEY (id_tienda)    REFERENCES TIENDA (id_tienda),
    CONSTRAINT CK_VETO_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT CK_VETO_estado CHECK (estado IN ('ACTIVO', 'LEVANTADO'))
);
GO

CREATE NONCLUSTERED INDEX IX_VETO_persona_estado ON VETO (id_persona, estado) INCLUDE (id_tienda, fecha_inicio, fecha_fin);
GO

/* ---------------------------------------------------------------------
   EVENTO_DETECCION: cada vez que el motor de inferencia reconoce a una
   persona vetada intentando ingresar a una tienda.
   - PENDIENTE: todavía no revisado (sin revisor ni fecha de revisión).
   - CONFIRMADO / DESCARTADO: revisado; puede no tener revisor si lo
     descartó automáticamente el sistema.
   --------------------------------------------------------------------- */
CREATE TABLE EVENTO_DETECCION (
    id_evento           INT IDENTITY(1,1) NOT NULL,
    id_persona          INT               NOT NULL,
    id_tienda           INT               NOT NULL,
    id_usuario_revisor  INT               NULL,
    fecha_hora          DATETIME2(0)      NOT NULL CONSTRAINT DF_EVENTO_fecha_hora DEFAULT (SYSDATETIME()),
    nivel_confianza     DECIMAL(5,4)      NOT NULL,
    referencia_captura  VARBINARY(MAX)    NOT NULL,
    estado_revision     VARCHAR(20)       NOT NULL CONSTRAINT DF_EVENTO_estado DEFAULT ('PENDIENTE'),
    fecha_revision      DATETIME2(0)      NULL,
    CONSTRAINT PK_EVENTO_DETECCION PRIMARY KEY (id_evento),
    CONSTRAINT FK_EVENTO_PERSONA FOREIGN KEY (id_persona)         REFERENCES PERSONA_VETADA (id_persona),
    CONSTRAINT FK_EVENTO_TIENDA  FOREIGN KEY (id_tienda)          REFERENCES TIENDA (id_tienda),
    CONSTRAINT FK_EVENTO_REVISOR FOREIGN KEY (id_usuario_revisor) REFERENCES USUARIO (id_usuario),
    CONSTRAINT CK_EVENTO_confianza CHECK (nivel_confianza BETWEEN 0 AND 1),
    CONSTRAINT CK_EVENTO_estado CHECK (estado_revision IN ('PENDIENTE', 'CONFIRMADO', 'DESCARTADO')),
    CONSTRAINT CK_EVENTO_revision CHECK (
        (estado_revision = 'PENDIENTE' AND id_usuario_revisor IS NULL AND fecha_revision IS NULL)
        OR
        (estado_revision <> 'PENDIENTE' AND fecha_revision IS NOT NULL AND fecha_revision >= fecha_hora)
    )
);
GO

CREATE NONCLUSTERED INDEX IX_EVENTO_tienda_fecha ON EVENTO_DETECCION (id_tienda, fecha_hora);
CREATE NONCLUSTERED INDEX IX_EVENTO_estado ON EVENTO_DETECCION (estado_revision) INCLUDE (id_persona, id_tienda, fecha_hora);
GO

/* ---------------------------------------------------------------------
   HISTORIAL_VETO: auditoría de altas, bajas y modificaciones de vetos.
   Lo completan los triggers. Los datos se guardan en formato JSON.
   --------------------------------------------------------------------- */
CREATE TABLE HISTORIAL_VETO (
    id_historial      INT IDENTITY(1,1) NOT NULL,
    id_veto           INT               NULL,
    id_usuario        INT               NOT NULL,
    accion            VARCHAR(10)       NOT NULL,
    fecha_hora        DATETIME2(0)      NOT NULL CONSTRAINT DF_HISTORIAL_fecha_hora DEFAULT (SYSDATETIME()),
    datos_anteriores  NVARCHAR(MAX)     NULL,
    datos_nuevos      NVARCHAR(MAX)     NULL,
    CONSTRAINT PK_HISTORIAL_VETO PRIMARY KEY (id_historial),
    CONSTRAINT FK_HISTORIAL_VETO    FOREIGN KEY (id_veto)    REFERENCES VETO (id_veto),
    CONSTRAINT FK_HISTORIAL_USUARIO FOREIGN KEY (id_usuario) REFERENCES USUARIO (id_usuario),
    CONSTRAINT CK_HISTORIAL_accion CHECK (accion IN ('ALTA', 'BAJA', 'MODIF')),
    CONSTRAINT CK_HISTORIAL_json_ant CHECK (datos_anteriores IS NULL OR ISJSON(datos_anteriores) = 1),
    CONSTRAINT CK_HISTORIAL_json_nue CHECK (datos_nuevos IS NULL OR ISJSON(datos_nuevos) = 1)
);
GO

CREATE NONCLUSTERED INDEX IX_HISTORIAL_veto ON HISTORIAL_VETO (id_veto, fecha_hora);
GO

PRINT 'Tablas creadas correctamente.';
GO
