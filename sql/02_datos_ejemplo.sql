/* =====================================================================
   TPI Base de Datos II - Equipo 03
   02 - Datos de ejemplo
   ---------------------------------------------------------------------
   Las fechas se calculan a partir de la fecha de ejecución (GETDATE()),
   así los vetos "vigentes" siguen vigentes y los "vencidos" siguen
   vencidos sin importar cuándo se corra el script.

   Ejecutar sobre una base recién creada con 01_creacion_tablas.sql
   (los comentarios con los id asumen que los IDENTITY arrancan en 1).
   ===================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- necesario por el índice filtrado de USUARIO_TIENDA
GO

USE BD2_TPI_G03;
GO

SET NOCOUNT ON;

DECLARE @hoy   DATE         = CAST(GETDATE() AS DATE);
DECLARE @ahora DATETIME2(0) = CAST(SYSDATETIME() AS DATETIME2(0));
DECLARE @base  DATETIME2(0) = CAST(@hoy AS DATETIME2(0));   -- hoy a las 00:00

BEGIN TRY
BEGIN TRANSACTION;

/* ---------------------------------------------------------------------
   ROL
   --------------------------------------------------------------------- */
INSERT INTO ROL (nombre, descripcion) VALUES
 (N'Administrador',           N'Acceso total: usuarios, tiendas, vetos y auditoría.'),           -- 1
 (N'Supervisor de seguridad', N'Registra incidentes, aplica y levanta vetos, revisa detecciones.'), -- 2
 (N'Operador de tienda',      N'Registra incidentes y revisa detecciones de sus tiendas.');       -- 3

/* ---------------------------------------------------------------------
   USUARIO  (contraseña de todos los usuarios de prueba: 1234)
   --------------------------------------------------------------------- */
INSERT INTO USUARIO (id_rol, nombre, email, hash_contrasena) VALUES
 (1, N'Administrador General', 'admin@seguridadtiendas.com',  CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2)), -- 1
 (2, N'Laura Méndez',          'lmendez@seguridadtiendas.com', CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2)), -- 2
 (2, N'Martín Ruiz',           'mruiz@seguridadtiendas.com',   CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2)), -- 3
 (3, N'Carla Gómez',           'cgomez@seguridadtiendas.com',  CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2)), -- 4
 (3, N'Diego Fernández',       'dfernandez@seguridadtiendas.com', CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2)), -- 5
 (3, N'Sofía Herrera',         'sherrera@seguridadtiendas.com', CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', '1234'), 2)); -- 6

/* ---------------------------------------------------------------------
   TIENDA
   --------------------------------------------------------------------- */
INSERT INTO TIENDA (nombre, direccion) VALUES
 (N'Sucursal Centro',     N'Av. Corrientes 1450, CABA'),          -- 1
 (N'Sucursal Palermo',    N'Av. Santa Fe 3720, CABA'),            -- 2
 (N'Sucursal Belgrano',   N'Av. Cabildo 2250, CABA'),             -- 3
 (N'Sucursal Caballito',  N'Av. Rivadavia 5100, CABA'),           -- 4
 (N'Sucursal San Isidro', N'Av. Centenario 980, San Isidro');     -- 5

/* ---------------------------------------------------------------------
   USUARIO_TIENDA  (fecha_hasta NULL = asignación vigente)
   Casos de prueba:
   - Carla (4) estuvo en Centro, la sacaron y la volvieron a asignar:
     dos filas para el mismo usuario y la misma tienda (corrección de la PK).
   - Diego (5) NO tiene acceso vigente a Centro (1) ni a Belgrano (3).
   - Sofía (6) tuvo acceso a San Isidro (5) pero ya no.
   - San Isidro (5) no tiene ningún usuario vigente.
   --------------------------------------------------------------------- */
INSERT INTO USUARIO_TIENDA (id_usuario, id_tienda, fecha_desde, fecha_hasta) VALUES
 (2, 1, DATEADD(DAY, -500, @hoy), NULL),
 (2, 2, DATEADD(DAY, -500, @hoy), NULL),
 (3, 3, DATEADD(DAY, -500, @hoy), NULL),
 (3, 4, DATEADD(DAY, -500, @hoy), NULL),
 (4, 1, DATEADD(DAY, -450, @hoy), DATEADD(DAY, -200, @hoy)),   -- asignación cerrada
 (4, 1, DATEADD(DAY,  -95, @hoy), NULL),                       -- reasignación vigente
 (5, 2, DATEADD(DAY, -400, @hoy), NULL),
 (5, 3, DATEADD(DAY, -400, @hoy), DATEADD(DAY, -180, @hoy)),   -- ya no tiene acceso a Belgrano
 (6, 4, DATEADD(DAY, -300, @hoy), NULL),
 (6, 5, DATEADD(DAY, -300, @hoy), DATEADD(DAY,  -30, @hoy));   -- ya no tiene acceso a San Isidro

/* ---------------------------------------------------------------------
   TIPO_INCIDENTE
   --------------------------------------------------------------------- */
INSERT INTO TIPO_INCIDENTE (nombre, descripcion) VALUES
 (N'Hurto',                N'Sustracción de mercadería sin violencia.'),                    -- 1
 (N'Agresión al personal', N'Agresión física o verbal grave a empleados de la tienda.'),    -- 2
 (N'Daños a la propiedad', N'Rotura intencional de instalaciones o mercadería.'),          -- 3
 (N'Fraude en el pago',    N'Uso de medios de pago adulterados o de terceros.'),           -- 4
 (N'Amenazas',             N'Amenazas a clientes o empleados dentro de la tienda.');       -- 5

/* ---------------------------------------------------------------------
   PERSONA_VETADA
   --------------------------------------------------------------------- */
INSERT INTO PERSONA_VETADA (nombre, apellido, documento, fecha_alta) VALUES
 (N'Julián',   N'Acosta',    '30111222', DATEADD(DAY, -420, @base)), -- 1
 (N'Romina',   N'Benítez',   '28333444', DATEADD(DAY, -300, @base)), -- 2
 (N'Hernán',   N'Castro',    '35555666', DATEADD(DAY, -250, @base)), -- 3
 (N'Lucas',    N'Domínguez', '36777888', DATEADD(DAY, -250, @base)), -- 4
 (N'Valeria',  N'Escobar',   '27999000', DATEADD(DAY, -200, @base)), -- 5
 (N'Gustavo',  N'Ferreyra',  '25123456', DATEADD(DAY, -150, @base)), -- 6
 (N'Natalia',  N'Giménez',   '38234567', DATEADD(DAY, -120, @base)), -- 7
 (N'Pablo',    N'Herrera',   '31345678', DATEADD(DAY,  -75, @base)), -- 8
 (N'Micaela',  N'Ibarra',    '40456789', DATEADD(DAY,  -60, @base)), -- 9
 (N'Sebastián',N'Juárez',    '33567890', DATEADD(DAY,  -45, @base)), -- 10
 (N'Florencia',N'Ledesma',   '37678901', DATEADD(DAY,  -30, @base)), -- 11
 (N'Ezequiel', N'Molina',    '39789012', DATEADD(DAY,  -20, @base)); -- 12

/* ---------------------------------------------------------------------
   INCIDENTE  (fecha = hace N días a las 15:00 / 18:00 / 11:00)
   --------------------------------------------------------------------- */
INSERT INTO INCIDENTE (id_tienda, id_tipo_incidente, id_usuario, fecha_hora, descripcion) VALUES
 (1, 1, 4, DATEADD(HOUR, 15, DATEADD(DAY, -420, @base)), N'Intentó retirar dos perfumes ocultos en la mochila. Retenido en la salida.'),          -- 1
 (2, 2, 5, DATEADD(HOUR, 18, DATEADD(DAY, -300, @base)), N'Empujó a una cajera tras una discusión por un cambio de producto.'),                   -- 2
 (1, 1, 4, DATEADD(HOUR, 11, DATEADD(DAY, -250, @base)), N'Dos personas actuando en conjunto: una distraía al vendedor mientras la otra cargaba mercadería.'), -- 3
 (3, 3, 3, DATEADD(HOUR, 15, DATEADD(DAY, -200, @base)), N'Rompió la vitrina de electrónica al ser advertida por seguridad.'),                   -- 4
 (4, 4, 6, DATEADD(HOUR, 18, DATEADD(DAY, -150, @base)), N'Pagó con una tarjeta denunciada como robada.'),                                      -- 5
 (2, 1, 5, DATEADD(HOUR, 11, DATEADD(DAY, -120, @base)), N'Hurto de indumentaria en probadores; se recuperó la mercadería.'),                     -- 6
 (1, 1, 4, DATEADD(HOUR, 15, DATEADD(DAY,  -90, @base)), N'Reincidente: nuevo intento de hurto de perfumería.'),                                -- 7
 (3, 5, 3, DATEADD(HOUR, 18, DATEADD(DAY,  -75, @base)), N'Amenazó al personal de seguridad cuando se le pidió revisar su bolso.'),            -- 8
 (4, 1, 6, DATEADD(HOUR, 11, DATEADD(DAY,  -60, @base)), N'Hurto de productos de almacén en reiteradas visitas, detectado por cámaras.'),        -- 9
 (2, 3, 2, DATEADD(HOUR, 15, DATEADD(DAY,  -45, @base)), N'Dañó el sistema antirrobo de la puerta de ingreso.'),                                -- 10
 (1, 2, 2, DATEADD(HOUR, 18, DATEADD(DAY,  -30, @base)), N'Agredió verbal y físicamente a un repositor.'),                                      -- 11
 (3, 1, 3, DATEADD(HOUR, 11, DATEADD(DAY,  -20, @base)), N'Hurto de herramientas eléctricas.'),                                               -- 12
 (4, 1, 6, DATEADD(HOUR, 15, DATEADD(DAY,  -10, @base)), N'Intento de hurto de una persona que ya tenía un veto vigente.');                     -- 13

/* ---------------------------------------------------------------------
   PERSONA_INCIDENTE
   - El incidente 3 involucra a dos personas (3 y 4).
   - Julián (1) y Romina (2) son reincidentes.
   --------------------------------------------------------------------- */
INSERT INTO PERSONA_INCIDENTE (id_persona, id_incidente) VALUES
 (1, 1), (2, 2), (3, 3), (4, 3), (5, 4), (6, 5), (7, 6),
 (1, 7), (8, 8), (9, 9), (10, 10), (11, 11), (12, 12), (2, 13);

/* ---------------------------------------------------------------------
   VETO   (id_tienda NULL = vale para todas las tiendas)
   Estado al día de hoy:
   - Vigentes: 2, 3 (solo Centro), 6, 8, 9, 10 (solo Caballito), 11, 12, 13 (solo Belgrano)
   - Vencidos (ACTIVO con fecha_fin pasada): 1, 4, 7
   - Levantado: 5
   Personas SIN veto vigente: 4, 5 y 7.
   Romina (2) tuvo un 2do incidente (13) pero no se le generó otro veto
   porque ya tenía uno vigente: es el caso que debe rechazar el trigger.
   --------------------------------------------------------------------- */
INSERT INTO VETO (id_persona, id_usuario, id_incidente, id_tienda, fecha_inicio, fecha_fin, estado, motivo) VALUES
 (1,  2, 1,  NULL, DATEADD(DAY, -420, @hoy), DATEADD(DAY, -240, @hoy), 'ACTIVO',    N'Hurto de perfumería. Veto por 180 días.'),                 -- 1 vencido
 (2,  2, 2,  NULL, DATEADD(DAY, -300, @hoy), NULL,                     'ACTIVO',    N'Agresión a personal de caja. Veto por tiempo indeterminado.'), -- 2 vigente
 (3,  2, 3,  1,    DATEADD(DAY, -250, @hoy), DATEADD(DAY,  115, @hoy), 'ACTIVO',    N'Hurto en banda en Sucursal Centro. Veto de un año solo para esa tienda.'), -- 3 vigente (tienda 1)
 (4,  2, 3,  1,    DATEADD(DAY, -250, @hoy), DATEADD(DAY,  -70, @hoy), 'ACTIVO',    N'Partícipe secundario del hurto en banda. Veto de 180 días.'), -- 4 vencido
 (5,  3, 4,  NULL, DATEADD(DAY, -200, @hoy), DATEADD(DAY, -100, @hoy), 'LEVANTADO', N'Daños a vitrina. Veto levantado tras acordar el pago de los daños.'), -- 5 levantado
 (6,  3, 5,  NULL, DATEADD(DAY, -150, @hoy), DATEADD(DAY,  215, @hoy), 'ACTIVO',    N'Fraude con tarjeta robada. Veto extendido a un año.'),     -- 6 vigente
 (7,  2, 6,  2,    DATEADD(DAY, -120, @hoy), DATEADD(DAY,  -30, @hoy), 'ACTIVO',    N'Hurto en probadores. Veto de 90 días en Sucursal Palermo.'), -- 7 vencido
 (1,  2, 7,  NULL, DATEADD(DAY,  -90, @hoy), NULL,                     'ACTIVO',    N'Reincidente en hurto. Veto por tiempo indeterminado.'),     -- 8 vigente
 (8,  3, 8,  NULL, DATEADD(DAY,  -75, @hoy), DATEADD(DAY,  290, @hoy), 'ACTIVO',    N'Amenazas al personal de seguridad. Veto de un año.'),       -- 9 vigente
 (9,  3, 9,  4,    DATEADD(DAY,  -60, @hoy), DATEADD(DAY,  120, @hoy), 'ACTIVO',    N'Hurtos reiterados en Sucursal Caballito. Veto de 180 días en esa tienda.'), -- 10 vigente (tienda 4)
 (10, 2, 10, NULL, DATEADD(DAY,  -45, @hoy), NULL,                     'ACTIVO',    N'Daño al sistema antirrobo. Veto por tiempo indeterminado.'), -- 11 vigente
 (11, 2, 11, NULL, DATEADD(DAY,  -30, @hoy), DATEADD(DAY,  335, @hoy), 'ACTIVO',    N'Agresión a repositor. Veto de un año.'),                    -- 12 vigente
 (12, 3, 12, 3,    DATEADD(DAY,  -20, @hoy), DATEADD(DAY,  160, @hoy), 'ACTIVO',    N'Hurto de herramientas. Veto de 180 días en Sucursal Belgrano.'); -- 13 vigente (tienda 3)

/* ---------------------------------------------------------------------
   EVENTO_DETECCION
   Mezcla de casos para las vistas, el SP de reporte y los triggers:
   - CONFIRMADO: persona con veto vigente, revisado por un usuario.
   - DESCARTADO sin revisor: lo descartó el sistema (veto vencido,
     levantado o que no aplica a esa tienda).
   - DESCARTADO con revisor: confianza baja, revisado a mano.
   - PENDIENTE: todavía sin revisar.
   --------------------------------------------------------------------- */
INSERT INTO EVENTO_DETECCION (id_persona, id_tienda, id_usuario_revisor, fecha_hora, nivel_confianza, referencia_captura, estado_revision, fecha_revision) VALUES
 (2,  2, 2,    DATEADD(HOUR, 10, DATEADD(DAY, -200, @base)), 0.9712, HASHBYTES('SHA2_256', 'captura-01'), 'CONFIRMADO', DATEADD(MINUTE, 10, DATEADD(HOUR, 10, DATEADD(DAY, -200, @base)))), -- 1
 (2,  3, 3,    DATEADD(HOUR, 17, DATEADD(DAY, -150, @base)), 0.9350, HASHBYTES('SHA2_256', 'captura-02'), 'CONFIRMADO', DATEADD(MINUTE,  8, DATEADD(HOUR, 17, DATEADD(DAY, -150, @base)))), -- 2
 (3,  1, 2,    DATEADD(HOUR, 12, DATEADD(DAY, -100, @base)), 0.9821, HASHBYTES('SHA2_256', 'captura-03'), 'CONFIRMADO', DATEADD(MINUTE,  5, DATEADD(HOUR, 12, DATEADD(DAY, -100, @base)))), -- 3
 (6,  4, 3,    DATEADD(HOUR, 19, DATEADD(DAY,  -80, @base)), 0.8890, HASHBYTES('SHA2_256', 'captura-04'), 'CONFIRMADO', DATEADD(MINUTE, 15, DATEADD(HOUR, 19, DATEADD(DAY,  -80, @base)))), -- 4
 (1,  1, 2,    DATEADD(HOUR, 16, DATEADD(DAY,  -60, @base)), 0.9654, HASHBYTES('SHA2_256', 'captura-05'), 'CONFIRMADO', DATEADD(MINUTE,  6, DATEADD(HOUR, 16, DATEADD(DAY,  -60, @base)))), -- 5
 (4,  1, NULL, DATEADD(HOUR, 11, DATEADD(DAY,  -50, @base)), 0.9100, HASHBYTES('SHA2_256', 'captura-06'), 'DESCARTADO', DATEADD(HOUR, 11, DATEADD(DAY,  -50, @base))),                     -- 6 veto vencido
 (5,  3, NULL, DATEADD(HOUR, 18, DATEADD(DAY,  -40, @base)), 0.8800, HASHBYTES('SHA2_256', 'captura-07'), 'DESCARTADO', DATEADD(HOUR, 18, DATEADD(DAY,  -40, @base))),                     -- 7 veto levantado
 (8,  3, 3,    DATEADD(HOUR, 13, DATEADD(DAY,  -35, @base)), 0.6120, HASHBYTES('SHA2_256', 'captura-08'), 'DESCARTADO', DATEADD(MINUTE, 20, DATEADD(HOUR, 13, DATEADD(DAY,  -35, @base)))), -- 8 confianza baja
 (9,  4, 6,    DATEADD(HOUR, 10, DATEADD(DAY,  -25, @base)), 0.9534, HASHBYTES('SHA2_256', 'captura-09'), 'CONFIRMADO', DATEADD(MINUTE,  4, DATEADD(HOUR, 10, DATEADD(DAY,  -25, @base)))), -- 9
 (10, 2, 5,    DATEADD(HOUR, 17, DATEADD(DAY,  -15, @base)), 0.9777, HASHBYTES('SHA2_256', 'captura-10'), 'CONFIRMADO', DATEADD(MINUTE,  7, DATEADD(HOUR, 17, DATEADD(DAY,  -15, @base)))), -- 10
 (11, 1, 2,    DATEADD(HOUR, 12, DATEADD(DAY,  -10, @base)), 0.9455, HASHBYTES('SHA2_256', 'captura-11'), 'CONFIRMADO', DATEADD(MINUTE,  9, DATEADD(HOUR, 12, DATEADD(DAY,  -10, @base)))), -- 11
 (7,  2, NULL, DATEADD(HOUR, 20, DATEADD(DAY,   -8, @base)), 0.9012, HASHBYTES('SHA2_256', 'captura-12'), 'DESCARTADO', DATEADD(HOUR, 20, DATEADD(DAY,   -8, @base))),                     -- 12 veto vencido
 (12, 3, 3,    DATEADD(HOUR, 15, DATEADD(DAY,   -6, @base)), 0.9301, HASHBYTES('SHA2_256', 'captura-13'), 'CONFIRMADO', DATEADD(MINUTE, 12, DATEADD(HOUR, 15, DATEADD(DAY,   -6, @base)))), -- 13
 (1,  2, NULL, DATEADD(HOUR, 11, DATEADD(DAY,   -4, @base)), 0.9688, HASHBYTES('SHA2_256', 'captura-14'), 'PENDIENTE',  NULL), -- 14
 (6,  1, NULL, DATEADD(HOUR, 18, DATEADD(DAY,   -3, @base)), 0.9120, HASHBYTES('SHA2_256', 'captura-15'), 'PENDIENTE',  NULL), -- 15
 (2,  4, NULL, DATEADD(HOUR, 10, DATEADD(DAY,   -2, @base)), 0.9890, HASHBYTES('SHA2_256', 'captura-16'), 'PENDIENTE',  NULL), -- 16
 (9,  2, NULL, DATEADD(HOUR, 16, DATEADD(DAY,   -2, @base)), 0.8450, HASHBYTES('SHA2_256', 'captura-17'), 'DESCARTADO', DATEADD(HOUR, 16, DATEADD(DAY,   -2, @base))),                     -- 17 su veto es solo para Caballito
 (11, 5, NULL, DATEADD(HOUR, 13, DATEADD(DAY,   -1, @base)), 0.9933, HASHBYTES('SHA2_256', 'captura-18'), 'PENDIENTE',  NULL), -- 18
 (3,  1, NULL, DATEADD(HOUR, 19, DATEADD(DAY,   -1, @base)), 0.7020, HASHBYTES('SHA2_256', 'captura-19'), 'PENDIENTE',  NULL), -- 19 confianza media
 (10, 5, NULL, DATEADD(HOUR, -3, @ahora),                    0.9560, HASHBYTES('SHA2_256', 'captura-20'), 'PENDIENTE',  NULL); -- 20 hoy

/* ---------------------------------------------------------------------
   HISTORIAL_VETO
   Carga histórica de la auditoría (de acá en adelante la completan los
   triggers): un ALTA por cada veto, la BAJA del veto 5 y una MODIF del
   veto 6 (se extendió su fecha de fin).
   --------------------------------------------------------------------- */
INSERT INTO HISTORIAL_VETO (id_veto, id_usuario, accion, fecha_hora, datos_anteriores, datos_nuevos)
SELECT
    v.id_veto,
    v.id_usuario,
    'ALTA',
    DATEADD(HOUR, 20, CAST(v.fecha_inicio AS DATETIME2(0))),
    NULL,
    (SELECT v.id_veto, v.id_persona, v.id_incidente, v.id_tienda, v.fecha_inicio,
            CASE v.id_veto
                WHEN 5 THEN NULL                                   -- se cargó sin fecha de fin
                WHEN 6 THEN DATEADD(DAY, 30, v.fecha_inicio)        -- originalmente 30 días
                ELSE v.fecha_fin
            END AS fecha_fin,
            'ACTIVO' AS estado,
            v.motivo
     FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
FROM VETO AS v
ORDER BY v.id_veto;

-- MODIF del veto 6: se extiende de 30 días a un año
INSERT INTO HISTORIAL_VETO (id_veto, id_usuario, accion, fecha_hora, datos_anteriores, datos_nuevos)
SELECT v.id_veto, 2, 'MODIF', DATEADD(HOUR, 10, CAST(DATEADD(DAY, 25, v.fecha_inicio) AS DATETIME2(0))),
       (SELECT DATEADD(DAY, 30, v.fecha_inicio) AS fecha_fin, N'Fraude con tarjeta robada. Veto de 30 días.' AS motivo
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
       (SELECT v.fecha_fin, v.motivo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
FROM VETO AS v WHERE v.id_veto = 6;

-- BAJA del veto 5: lo levanta el administrador
INSERT INTO HISTORIAL_VETO (id_veto, id_usuario, accion, fecha_hora, datos_anteriores, datos_nuevos)
SELECT v.id_veto, 1, 'BAJA', DATEADD(HOUR, 12, CAST(v.fecha_fin AS DATETIME2(0))),
       (SELECT 'ACTIVO' AS estado, CAST(NULL AS DATE) AS fecha_fin FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
       (SELECT v.estado, v.fecha_fin FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
FROM VETO AS v WHERE v.id_veto = 5;

COMMIT TRANSACTION;
PRINT 'Datos de ejemplo cargados correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Error al cargar los datos: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO

/* Resumen rápido de lo cargado */
SELECT 'ROL' AS tabla, COUNT(*) AS filas FROM ROL
UNION ALL SELECT 'USUARIO', COUNT(*) FROM USUARIO
UNION ALL SELECT 'TIENDA', COUNT(*) FROM TIENDA
UNION ALL SELECT 'USUARIO_TIENDA', COUNT(*) FROM USUARIO_TIENDA
UNION ALL SELECT 'TIPO_INCIDENTE', COUNT(*) FROM TIPO_INCIDENTE
UNION ALL SELECT 'PERSONA_VETADA', COUNT(*) FROM PERSONA_VETADA
UNION ALL SELECT 'INCIDENTE', COUNT(*) FROM INCIDENTE
UNION ALL SELECT 'PERSONA_INCIDENTE', COUNT(*) FROM PERSONA_INCIDENTE
UNION ALL SELECT 'VETO', COUNT(*) FROM VETO
UNION ALL SELECT 'EVENTO_DETECCION', COUNT(*) FROM EVENTO_DETECCION
UNION ALL SELECT 'HISTORIAL_VETO', COUNT(*) FROM HISTORIAL_VETO;
GO
