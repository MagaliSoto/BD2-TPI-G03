/* =====================================================================
   TPI Base de Datos II - Equipo 03
   03 - Funciones de usuario (UDF)
   Responsable: Santiago Gonzalez Trejo
   ---------------------------------------------------------------------
   A completar:
   - fn_veto_vigente(@id_persona, @id_tienda): 1 si la persona tiene un
     veto ACTIVO, con fecha_fin NULL o >= hoy, y que aplica a esa tienda
     (id_tienda NULL = todas las tiendas).
   - fn_cantidad_incidentes(@id_persona)
   ===================================================================== */

USE BD2_TPI_G03;
GO

-- Indica si una persona tiene un veto vigente para una tienda.
CREATE FUNCTION dbo.fn_veto_vigente
(
    @id_persona INT,
    @id_tienda INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @resultado BIT;
    DECLARE @hoy DATE;

    SET @resultado = 0;
    SET @hoy = CAST(GETDATE() AS DATE);

    IF EXISTS
    (
        SELECT 1
        FROM VETO
        WHERE id_persona = @id_persona
          AND estado = 'ACTIVO'
          AND fecha_inicio <= @hoy
          AND (fecha_fin IS NULL OR fecha_fin >= @hoy)
          AND (id_tienda IS NULL OR id_tienda = @id_tienda)
    )
    BEGIN
        SET @resultado = 1;
    END;

    RETURN @resultado;
END;
GO

-- Devuelve la cantidad de incidentes asociados a una persona.
CREATE FUNCTION dbo.fn_cantidad_incidentes
(
    @id_persona INT
)
RETURNS INT
AS
BEGIN
    DECLARE @cantidad INT;

    SELECT @cantidad = COUNT(*)
    FROM PERSONA_INCIDENTE
    WHERE id_persona = @id_persona;

    RETURN @cantidad;
END;
GO