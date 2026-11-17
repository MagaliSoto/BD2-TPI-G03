/* =====================================================================
   TPI Base de Datos II - Equipo 03
   07 - Pruebas para el video (casos de éxito y de error)
   Responsable: Todos (cada uno agrega las pruebas de sus objetos)
   ---------------------------------------------------------------------
   A completar:
   Una sección por objeto, con el EXEC/INSERT/DELETE y un SELECT de
   antes y después para mostrar el efecto.
   ===================================================================== */

USE BD2_TPI_G03;
GO

/* 
   Pruebas de funciones y vistas - S Agustin Gonzalez Trejo
   Los resultados esperados corresponden a los datos de ejemplo.
   */

-- La persona 2 tiene un veto global, asi que devuelve 1 en las dos tiendas.
SELECT
    dbo.fn_veto_vigente(2, 1) AS GlobalEnCentro,
    dbo.fn_veto_vigente(2, 2) AS GlobalEnPalermo;
GO

-- La persona 3 esta vetada en Centro, pero no en Palermo.
-- Esperariammos en este caso 1 y 0.
SELECT
    dbo.fn_veto_vigente(3, 1) AS EnCentro,
    dbo.fn_veto_vigente(3, 2) AS EnPalermo;
GO

-- Un veto vencido o levantado ya no debe impedir el ingreso.
-- Los dos resultados deberian de ser 0.
SELECT
    dbo.fn_veto_vigente(4, 1) AS VetoVencido,
    dbo.fn_veto_vigente(5, 1) AS VetoLevantado;
GO

-- Contamos los incidentes de dos personas y probamos un ID que no existe.
-- Esperamos 2, 1 y 0.
SELECT
    dbo.fn_cantidad_incidentes(1) AS PersonaReincidente,
    dbo.fn_cantidad_incidentes(3) AS PersonaConUnIncidente,
    dbo.fn_cantidad_incidentes(-1) AS PersonaInexistente;
GO

-- Consultamos los vetos que siguen vigentes.
-- Con los datos de ejemplos deberian de aparecer 9.
SELECT *
FROM dbo.vw_personas_vetadas_vigentes
ORDER BY id_persona, id_veto;
GO

-- Vemos las detecciones que todavia falta revisar.
-- Deberian aparecer 6, todas en modo de pendientes.
SELECT *
FROM dbo.vw_detecciones_pendientes
ORDER BY fecha_hora, id_evento;
GO

-- Vemos cuantos incidentes hubo en cada tienda, separados por tipo.
SELECT *
FROM dbo.vw_incidentes_por_tienda
ORDER BY tienda, tipo_incidente;
GO

-- Comparamos el total de la vista con el de la tabla.
-- Los dos deberian dar 13.
SELECT
    (SELECT SUM(cantidad_incidentes)
     FROM dbo.vw_incidentes_por_tienda) AS TotalEnVista,
    (SELECT COUNT(*)
     FROM dbo.INCIDENTE) AS TotalEnTabla;
GO
/*
   Pruebas de triggers - Cristian Tesaglio
   Correr después de las pruebas de funciones y vistas (modifican datos).
   Los resultados esperados corresponden a los datos de ejemplo.
   */

/* ---------- 1) trg_VETO_alta ---------- */

-- Éxito: Lucas Domínguez (4) no tiene veto vigente. Se le aplica uno en Palermo.
-- Esperamos el veto nuevo y un ALTA en HISTORIAL_VETO con los datos en JSON.
INSERT INTO VETO (id_persona, id_usuario, id_incidente, id_tienda, fecha_inicio, fecha_fin, motivo)
VALUES (4, 2, NULL, 2, CAST(GETDATE() AS DATE), DATEADD(DAY, 90, CAST(GETDATE() AS DATE)),
        N'Prueba de trigger: veto de 90 días en Sucursal Palermo.');

SELECT TOP 1 * FROM HISTORIAL_VETO ORDER BY id_historial DESC;
GO

-- Éxito: Hernán Castro (3) está vetado solo en Centro, así que en Palermo se puede.
INSERT INTO VETO (id_persona, id_usuario, id_incidente, id_tienda, fecha_inicio, fecha_fin, motivo)
VALUES (3, 2, NULL, 2, CAST(GETDATE() AS DATE), NULL,
        N'Prueba de trigger: veto en Palermo, no se pisa con el de Centro.');

SELECT * FROM VETO WHERE id_persona = 3 ORDER BY id_veto;
GO

-- Error: Romina Benítez (2) ya tiene un veto global por tiempo indeterminado.
-- Es el caso del incidente 13: el trigger tiene que rechazarlo.
BEGIN TRY
    INSERT INTO VETO (id_persona, id_usuario, id_incidente, id_tienda, fecha_inicio, fecha_fin, motivo)
    VALUES (2, 3, 13, 4, CAST(GETDATE() AS DATE), NULL,
            N'Prueba de trigger: debería rechazarse.');
END TRY
BEGIN CATCH
    PRINT 'Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Error: Hernán Castro (3) tiene veto en Centro; uno para toda la empresa lo incluye.
BEGIN TRY
    INSERT INTO VETO (id_persona, id_usuario, id_incidente, id_tienda, fecha_inicio, fecha_fin, motivo)
    VALUES (3, 2, NULL, NULL, CAST(GETDATE() AS DATE), NULL,
            N'Prueba de trigger: debería rechazarse.');
END TRY
BEGIN CATCH
    PRINT 'Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- No se tiene que haber guardado ninguno de los dos rechazados.
-- Esperamos 1 veto para la persona 2 y 2 para la persona 3.
SELECT
    (SELECT COUNT(*) FROM VETO WHERE id_persona = 2) AS VetosRomina,
    (SELECT COUNT(*) FROM VETO WHERE id_persona = 3) AS VetosHernan;
GO

/* ---------- 2) trg_EVENTO_DETECCION_descarte ---------- */

-- Insertamos 4 detecciones juntas:
--   a) Valeria Escobar (5) en Centro: su veto está levantado      -> DESCARTADO
--   b) Micaela Ibarra (9) en Palermo: su veto es solo de Caballito -> DESCARTADO
--   c) Romina Benítez (2) en Centro con confianza 0.55             -> DESCARTADO
--   d) Romina Benítez (2) en Centro con confianza 0.97             -> PENDIENTE
INSERT INTO EVENTO_DETECCION (id_persona, id_tienda, nivel_confianza, referencia_captura) VALUES
 (5, 1, 0.9500, HASHBYTES('SHA2_256', 'prueba-trigger-a')),
 (9, 2, 0.9300, HASHBYTES('SHA2_256', 'prueba-trigger-b')),
 (2, 1, 0.5500, HASHBYTES('SHA2_256', 'prueba-trigger-c')),
 (2, 1, 0.9700, HASHBYTES('SHA2_256', 'prueba-trigger-d'));

SELECT TOP 4 id_evento, id_persona, id_tienda, nivel_confianza,
       estado_revision, id_usuario_revisor, fecha_hora, fecha_revision
FROM EVENTO_DETECCION
ORDER BY id_evento DESC;
GO

/* ---------- 3) trg_VETO_baja_logica ---------- */

-- Florencia Ledesma (11) tiene el veto 12 vigente en toda la empresa.
-- Lo "borra" el administrador (1), indicado por SESSION_CONTEXT.
-- Antes: ACTIVO y fn_veto_vigente = 1.
SELECT id_veto, estado, fecha_fin, dbo.fn_veto_vigente(11, 1) AS VigenteEnCentro
FROM VETO WHERE id_veto = 12;

EXEC sp_set_session_context N'id_usuario', 1;
DELETE FROM VETO WHERE id_veto = 12;
EXEC sp_set_session_context N'id_usuario', NULL;

-- Después: la fila sigue existiendo, LEVANTADO con fecha_fin = hoy y fn_veto_vigente = 0.
SELECT id_veto, estado, fecha_fin, dbo.fn_veto_vigente(11, 1) AS VigenteEnCentro
FROM VETO WHERE id_veto = 12;

-- Un solo registro BAJA hecho por el usuario 1 (no se duplica como MODIF).
SELECT * FROM HISTORIAL_VETO WHERE id_veto = 12 ORDER BY id_historial;
GO

/* ---------- 4) trg_VETO_modificacion (bonus) ---------- */

-- Se extiende 60 días el veto 10 (Micaela Ibarra, Caballito).
-- Esperamos un MODIF con la fila completa antes y después.
UPDATE VETO
SET fecha_fin = DATEADD(DAY, 60, fecha_fin),
    motivo    = N'Hurtos reiterados en Sucursal Caballito. Veto extendido 60 días.'
WHERE id_veto = 10;

SELECT * FROM HISTORIAL_VETO WHERE id_veto = 10 ORDER BY id_historial;
GO

-- Un UPDATE que no cambia nada no tiene que generar auditoría.
-- Esperamos la misma cantidad antes y después.
DECLARE @antes INT = (SELECT COUNT(*) FROM HISTORIAL_VETO WHERE id_veto = 10);
UPDATE VETO SET motivo = motivo WHERE id_veto = 10;
SELECT @antes AS RegistrosAntes,
       (SELECT COUNT(*) FROM HISTORIAL_VETO WHERE id_veto = 10) AS RegistrosDespues;
GO
/* =====================================================================
   Pruebas de procedimientos almacenados - Evelyn Baini
   ===================================================================== */

-- 1. Prueba exitosa de sp_reporte_detecciones
-- Consultar detecciones de la tienda 2 con confianza >= 0.9000.

EXEC dbo.sp_reporte_detecciones
    @id_tienda = 2,
    @desde = '2026-01-01',
    @hasta = '2026-12-31T23:59:59',
    @confianza_min = 0.9000;
GO

-- 2. Prueba de error: fechas incorrectas

BEGIN TRY
    EXEC dbo.sp_reporte_detecciones
        @id_tienda = 2,
        @desde = '2026-12-31',
        @hasta = '2026-01-01',
        @confianza_min = 0.9000;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- 3. Prueba de error: confianza fuera de rango

BEGIN TRY
    EXEC dbo.sp_reporte_detecciones
        @id_tienda = 2,
        @desde = '2026-01-01',
        @hasta = '2026-12-31',
        @confianza_min = 1.5000;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- 4. Prueba de error: tienda inexistente

BEGIN TRY
    EXEC dbo.sp_reporte_detecciones
        @id_tienda = -1,
        @desde = '2026-01-01',
        @hasta = '2026-12-31',
        @confianza_min = 0.9000;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- 5. Prueba de error: usuario no autorizado

BEGIN TRY
    EXEC dbo.sp_registrar_incidente
        @id_usuario = -1,
        @id_tienda = 2,
        @id_tipo_incidente = 1,
        @nombre = 'Persona',
        @apellido = 'Prueba',
        @documento = '99999999',
        @descripcion = 'Prueba de usuario no autorizado',
        @motivo = 'Prueba de validacion',
        @fecha_fin = '2026-12-31',
        @id_tienda_veto = 2;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- 6. Prueba de error: tipo de incidente inexistente

BEGIN TRY
    EXEC dbo.sp_registrar_incidente
        @id_usuario = 2,
        @id_tienda = 2,
        @id_tipo_incidente = -1,
        @nombre = 'Persona',
        @apellido = 'Prueba',
        @documento = '99999999',
        @descripcion = 'Prueba de tipo de incidente inexistente',
        @motivo = 'Prueba de validacion',
        @fecha_fin = '2026-12-31',
        @id_tienda_veto = 2;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- 7. Prueba de error: tienda del veto inexistente

BEGIN TRY
    EXEC dbo.sp_registrar_incidente
        @id_usuario = 2,
        @id_tienda = 2,
        @id_tipo_incidente = 1,
        @nombre = 'Persona',
        @apellido = 'Prueba',
        @documento = '99999999',
        @descripcion = 'Prueba de tienda del veto inexistente',
        @motivo = 'Prueba de validacion',
        @fecha_fin = '2026-12-31',
        @id_tienda_veto = -1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- 8. Prueba exitosa de registro de incidente y veto
-- Mostrar datos antes y despues.
-- Deshacer los cambios al terminar.

SELECT *
FROM dbo.PERSONA_VETADA
WHERE documento = '88888888';

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC dbo.sp_registrar_incidente
        @id_usuario = 2,
        @id_tienda = 2,
        @id_tipo_incidente = 1,
        @nombre = 'Persona',
        @apellido = 'Demostracion',
        @documento = '88888888',
        @descripcion = 'Prueba exitosa de registro',
        @motivo = 'Hurto de mercaderia',
        @fecha_fin = '2026-12-31',
        @id_tienda_veto = 2;

    -- persona registrada
    SELECT *
    FROM dbo.PERSONA_VETADA
    WHERE documento = '88888888';

    -- incidente registrado
    SELECT I.*
    FROM dbo.INCIDENTE I
    INNER JOIN dbo.PERSONA_INCIDENTE PI
        ON I.id_incidente = PI.id_incidente
    INNER JOIN dbo.PERSONA_VETADA P
        ON PI.id_persona = P.id_persona
    WHERE P.documento = '88888888';

    -- veto registrado
    SELECT V.*
    FROM dbo.VETO V
    INNER JOIN dbo.PERSONA_VETADA P
        ON V.id_persona = P.id_persona
    WHERE P.documento = '88888888';

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- Comprobar que no quedaron datos de prueba
SELECT *
FROM dbo.PERSONA_VETADA
WHERE documento = '88888888';
GO
