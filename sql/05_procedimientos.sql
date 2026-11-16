/* =====================================================================
   TPI Base de Datos II - Equipo 03
   05 - Procedimientos almacenados
   Responsable: Evelyn Baini
   ---------------------------------------------------------------------
   Procedimientos implementados:
   - sp_reporte_detecciones(@id_tienda, @desde, @hasta, @confianza_min)
   - sp_registrar_incidente(...): valida acceso vigente del usuario a la
     tienda en USUARIO_TIENDA (fecha_hasta NULL), crea persona si no
     existe, incidente, PERSONA_INCIDENTE y VETO (con id_incidente).
     Transaccion + TRY/CATCH.
   ===================================================================== */

USE BD2_TPI_G03;
GO

-- 1. Procedimiento para consultar detecciones
CREATE OR ALTER PROCEDURE dbo.sp_reporte_detecciones
    @id_tienda INT,
    @desde DATETIME2,
    @hasta DATETIME2,
    @confianza_min DECIMAL(5,4)
AS
BEGIN
    BEGIN TRY

        -- Validar las fechas
        IF @desde > @hasta
        BEGIN
            RAISERROR('La fecha desde no puede ser posterior a la fecha hasta.', 16, 1);
            RETURN;
        END;

        -- Validar el nivel de confianza
        IF @confianza_min < 0 OR @confianza_min > 1
        BEGIN
            RAISERROR('La confianza debe estar entre 0 y 1.', 16, 1);
            RETURN;
        END;

        -- Validar que la tienda exista
        IF NOT EXISTS (
            SELECT 1
            FROM TIENDA
            WHERE id_tienda = @id_tienda
        )
        BEGIN
            RAISERROR('La tienda indicada no existe.', 16, 1);
            RETURN;
        END;

        -- Consultar detecciones con datos de persona y tienda
        SELECT
            E.id_evento,
            P.nombre AS nombre_persona,
            P.apellido AS apellido_persona,
            P.documento,
            T.nombre AS nombre_tienda,
            E.fecha_hora,
            E.nivel_confianza,
            E.estado_revision
        FROM EVENTO_DETECCION E
        INNER JOIN PERSONA_VETADA P
            ON E.id_persona = P.id_persona
        INNER JOIN TIENDA T
            ON E.id_tienda = T.id_tienda
        WHERE E.id_tienda = @id_tienda
          AND E.fecha_hora >= @desde
          AND E.fecha_hora <= @hasta
          AND E.nivel_confianza >= @confianza_min;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- 2. Procedimiento para registrar incidentes y vetos
CREATE OR ALTER PROCEDURE dbo.sp_registrar_incidente
    @id_usuario INT,
    @id_tienda INT,
    @id_tipo_incidente INT,
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @documento VARCHAR(20),
    @descripcion NVARCHAR(2000),
    @motivo NVARCHAR(500),
    @fecha_fin DATE,
    @id_tienda_veto INT = NULL
AS
BEGIN
    DECLARE @id_persona INT;
    DECLARE @id_incidente INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Verificar que el usuario este autorizado
        IF NOT EXISTS (
            SELECT 1
            FROM USUARIO_TIENDA
            WHERE id_usuario = @id_usuario
              AND id_tienda = @id_tienda
              AND fecha_desde <= CAST(GETDATE() AS DATE)
              AND fecha_hasta IS NULL
        )
        BEGIN
            RAISERROR('El usuario no esta autorizado en esta tienda.', 16, 1);
        END;

        -- 2. Validar la fecha de finalizacion del veto
        IF @fecha_fin < CAST(GETDATE() AS DATE)
        BEGIN
            RAISERROR('La fecha de fin no puede ser anterior a hoy.', 16, 1);
        END;

        -- 3. Validar que el tipo de incidente exista
        IF NOT EXISTS (
            SELECT 1
            FROM TIPO_INCIDENTE
            WHERE id_tipo_incidente = @id_tipo_incidente
        )
        BEGIN
            RAISERROR('El tipo de incidente indicado no existe.', 16, 1);
        END;

        -- 4. Validar que la tienda del veto exista
        IF @id_tienda_veto IS NOT NULL
           AND NOT EXISTS (
               SELECT 1
               FROM TIENDA
               WHERE id_tienda = @id_tienda_veto
           )
        BEGIN
            RAISERROR('La tienda del veto indicada no existe.', 16, 1);
        END;

        -- 5. Buscar si la persona ya existe
        SELECT @id_persona = id_persona
        FROM PERSONA_VETADA
        WHERE documento = @documento;

        -- 6. Registrar a la persona si no existe
        IF @id_persona IS NULL
        BEGIN
            INSERT INTO PERSONA_VETADA
                (nombre, apellido, documento)
            VALUES
                (@nombre, @apellido, @documento);

            SET @id_persona = SCOPE_IDENTITY();
        END;

        -- 7. Registrar el incidente
        INSERT INTO INCIDENTE
            (id_tienda, id_tipo_incidente, id_usuario,
             fecha_hora, descripcion)
        VALUES
            (@id_tienda, @id_tipo_incidente, @id_usuario,
             DATEADD(SECOND, -1, GETDATE()), @descripcion);

        SET @id_incidente = SCOPE_IDENTITY();

        -- 8. Relacionar la persona con el incidente
        INSERT INTO PERSONA_INCIDENTE
            (id_persona, id_incidente)
        VALUES
            (@id_persona, @id_incidente);

        -- 9. Registrar el veto
        INSERT INTO VETO
            (id_persona, id_usuario, id_incidente,
             id_tienda, fecha_inicio, fecha_fin,
             estado, motivo)
        VALUES
            (@id_persona, @id_usuario, @id_incidente,
             @id_tienda_veto, CAST(GETDATE() AS DATE),
             @fecha_fin, 'ACTIVO', @motivo);

        COMMIT TRANSACTION;

        PRINT 'Incidente y veto registrados correctamente.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
