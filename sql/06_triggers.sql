/* =====================================================================
   TPI Base de Datos II - Equipo 03
   06 - Triggers
   Responsable: Cristian Tesaglio
   ---------------------------------------------------------------------
   - trg_VETO_alta (AFTER INSERT en VETO): rechaza si ya hay un veto
     vigente que se superpone y registra ALTA en HISTORIAL_VETO
     (datos en JSON con FOR JSON PATH).
   - trg_EVENTO_DETECCION_descarte (AFTER INSERT en EVENTO_DETECCION):
     si no hay veto vigente para esa persona en esa tienda o la
     confianza es baja -> DESCARTADO con fecha_revision.
   - trg_VETO_baja_logica (INSTEAD OF DELETE en VETO): estado LEVANTADO
     + fecha_fin = hoy, registra BAJA.
   - trg_VETO_modificacion (AFTER UPDATE en VETO, bonus): registra MODIF
     con los datos anteriores y nuevos.

   Usuario que queda en la auditoría:
   La web puede indicar quién hace la operación con
       EXEC sp_set_session_context N'id_usuario', <id>;
   Si no lo indica, se usa el id_usuario del propio veto.
   ===================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE BD2_TPI_G03;
GO

/* ---------------------------------------------------------------------
   1) INSERT en VETO
   Dos vetos se superponen cuando son de la misma persona, se pisan en
   fechas (fecha_fin NULL = sin fin) y se pisan en alcance (alguno de
   los dos es para toda la empresa o los dos son de la misma tienda).
   Solo se compara contra vetos ACTIVOS que no estén vencidos.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_VETO_alta
ON dbo.VETO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN VETO v
            ON  v.id_persona = i.id_persona
            AND v.id_veto   <> i.id_veto          -- no compararlo consigo mismo
        WHERE i.estado = 'ACTIVO'
          AND v.estado = 'ACTIVO'
          AND (v.fecha_fin IS NULL OR v.fecha_fin >= @hoy)        -- el existente no está vencido
          AND v.fecha_inicio <= ISNULL(i.fecha_fin, '9999-12-31') -- se pisan en fechas
          AND i.fecha_inicio <= ISNULL(v.fecha_fin, '9999-12-31')
          AND (v.id_tienda IS NULL                                -- se pisan en alcance
               OR i.id_tienda IS NULL
               OR v.id_tienda = i.id_tienda)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'La persona ya tiene un veto vigente que se superpone con el nuevo (mismas fechas y misma tienda o toda la empresa).', 1;
    END;

    INSERT INTO HISTORIAL_VETO (id_veto, id_usuario, accion, datos_anteriores, datos_nuevos)
    SELECT
        i.id_veto,
        ISNULL(TRY_CAST(SESSION_CONTEXT(N'id_usuario') AS INT), i.id_usuario),
        'ALTA',
        NULL,
        (SELECT i.id_veto, i.id_persona, i.id_incidente, i.id_tienda,
                i.fecha_inicio, i.fecha_fin, i.estado, i.motivo
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i;
END;
GO

/* ---------------------------------------------------------------------
   2) INSERT en EVENTO_DETECCION
   Solo toca los eventos que entran como PENDIENTE. Si la persona no
   tiene veto vigente en esa tienda (fn_veto_vigente) o la confianza es
   menor al umbral, lo descarta el sistema (sin revisor).
   Umbral 0.70: con los datos de ejemplo, 0.6120 es baja y 0.7020 queda
   pendiente como confianza media.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_EVENTO_DETECCION_descarte
ON dbo.EVENTO_DETECCION
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @confianza_minima DECIMAL(5,4) = 0.7000;
    DECLARE @ahora DATETIME2(0) = CAST(SYSDATETIME() AS DATETIME2(0));

    UPDATE e
    SET e.estado_revision    = 'DESCARTADO',
        e.id_usuario_revisor = NULL,
        -- el CHECK exige fecha_revision >= fecha_hora
        e.fecha_revision     = CASE WHEN @ahora >= e.fecha_hora THEN @ahora ELSE e.fecha_hora END
    FROM EVENTO_DETECCION e
    INNER JOIN inserted i ON i.id_evento = e.id_evento
    WHERE i.estado_revision = 'PENDIENTE'
      AND (
            dbo.fn_veto_vigente(i.id_persona, i.id_tienda) = 0
            OR i.nivel_confianza < @confianza_minima
          );
END;
GO

/* ---------------------------------------------------------------------
   3) INSTEAD OF DELETE en VETO
   Los vetos no se borran: pasan a LEVANTADO con fecha_fin = hoy.
   - Si la fecha_fin ya era anterior a hoy, se deja como estaba.
   - Si el veto todavía no empezó, fecha_fin = fecha_inicio (por el
     CHECK fecha_fin >= fecha_inicio).
   - Los que ya estaban LEVANTADOS se ignoran.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_VETO_baja_logica
ON dbo.VETO
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    UPDATE v
    SET v.estado    = 'LEVANTADO',
        v.fecha_fin = CASE
                          WHEN v.fecha_inicio > @hoy THEN v.fecha_inicio
                          WHEN v.fecha_fin IS NULL OR v.fecha_fin > @hoy THEN @hoy
                          ELSE v.fecha_fin
                      END
    FROM VETO v
    INNER JOIN deleted d ON d.id_veto = v.id_veto
    WHERE d.estado = 'ACTIVO';

    INSERT INTO HISTORIAL_VETO (id_veto, id_usuario, accion, datos_anteriores, datos_nuevos)
    SELECT
        d.id_veto,
        ISNULL(TRY_CAST(SESSION_CONTEXT(N'id_usuario') AS INT), d.id_usuario),
        'BAJA',
        (SELECT d.estado, d.fecha_fin
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT v.estado, v.fecha_fin
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM deleted d
    INNER JOIN VETO v ON v.id_veto = d.id_veto
    WHERE d.estado = 'ACTIVO';
END;
GO

/* ---------------------------------------------------------------------
   4) UPDATE en VETO
   Registra MODIF con la fila completa antes y después.
   - Solo las filas que cambiaron de verdad (el EXCEPT compara bien los
     NULL), así un UPDATE que no cambia nada no ensucia la auditoría.
   - Si el UPDATE viene de trg_VETO_baja_logica no hace nada, porque esa
     baja ya queda registrada como BAJA.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_VETO_modificacion
ON dbo.VETO
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(OBJECT_ID('dbo.trg_VETO_baja_logica')) > 0
        RETURN;

    INSERT INTO HISTORIAL_VETO (id_veto, id_usuario, accion, datos_anteriores, datos_nuevos)
    SELECT
        i.id_veto,
        ISNULL(TRY_CAST(SESSION_CONTEXT(N'id_usuario') AS INT), i.id_usuario),
        'MODIF',
        (SELECT d.id_veto, d.id_persona, d.id_usuario, d.id_incidente, d.id_tienda,
                d.fecha_inicio, d.fecha_fin, d.estado, d.motivo
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i.id_veto, i.id_persona, i.id_usuario, i.id_incidente, i.id_tienda,
                i.fecha_inicio, i.fecha_fin, i.estado, i.motivo
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted i
    INNER JOIN deleted d ON d.id_veto = i.id_veto
    WHERE EXISTS
    (
        SELECT i.id_persona, i.id_usuario, i.id_incidente, i.id_tienda,
               i.fecha_inicio, i.fecha_fin, i.estado, i.motivo
        EXCEPT
        SELECT d.id_persona, d.id_usuario, d.id_incidente, d.id_tienda,
               d.fecha_inicio, d.fecha_fin, d.estado, d.motivo
    );
END;
GO

PRINT 'Triggers creados correctamente.';
GO


