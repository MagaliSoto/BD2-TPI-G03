/* =====================================================================
   TPI Base de Datos II - Equipo 03
   04 - Vistas
   Responsable: Santiago Gonzalez Trejo
   ---------------------------------------------------------------------
   A completar:
   - vw_personas_vetadas_vigentes (usa las funciones de 03)
   - vw_detecciones_pendientes
   - vw_incidentes_por_tienda
   ===================================================================== */

USE BD2_TPI_G03;
GO

-- Muestra los vetos vigentes y los datos de cada persona, lo dejo pendiente xq no se si esta correcto, a revisar.
CREATE VIEW dbo.vw_personas_vetadas_vigentes AS
SELECT
    p.id_persona,
    p.nombre,
    p.apellido,
    p.documento,
    v.id_veto,
    v.id_tienda,
    CASE
        WHEN v.id_tienda IS NULL THEN 'Toda la empresa'
        ELSE t.nombre
    END AS alcance_veto,
    v.fecha_inicio,
    v.fecha_fin,
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), v.fecha_fin)
        AS dias_restantes,
    v.motivo,
    dbo.fn_veto_vigente(p.id_persona, v.id_tienda)
        AS veto_vigente,
    dbo.fn_cantidad_incidentes(p.id_persona)
        AS cantidad_incidentes
FROM PERSONA_VETADA p
INNER JOIN VETO v ON p.id_persona = v.id_persona
LEFT JOIN TIENDA t ON v.id_tienda = t.id_tienda
WHERE v.estado = 'ACTIVO'
  AND v.fecha_inicio <= CAST(GETDATE() AS DATE)
  AND (
      v.fecha_fin IS NULL
      OR v.fecha_fin >= CAST(GETDATE() AS DATE)
  );
GO

-- Muestra las detecciones que no fueron revisadas hasta el momento.

CREATE VIEW dbo.vw_detecciones_pendientes AS
SELECT
    e.id_evento,
    e.id_persona,
    p.nombre,
    p.apellido,
    p.documento,
    e.id_tienda,
    t.nombre AS tienda,
    e.fecha_hora,
    e.nivel_confianza,
    e.estado_revision
FROM EVENTO_DETECCION e
INNER JOIN PERSONA_VETADA p
    ON e.id_persona = p.id_persona
INNER JOIN TIENDA t
    ON e.id_tienda = t.id_tienda
WHERE e.estado_revision = 'PENDIENTE';
GO

-- Resume los incidentes por tienda y tipo de incidente.
CREATE VIEW dbo.vw_incidentes_por_tienda AS
SELECT
    t.id_tienda,
    t.nombre AS tienda,
    ti.id_tipo_incidente,
    ti.nombre AS tipo_incidente,
    COUNT(*) AS cantidad_incidentes,
    MAX(i.fecha_hora) AS fecha_ultimo_incidente
FROM INCIDENTE i
INNER JOIN TIENDA t
    ON i.id_tienda = t.id_tienda
INNER JOIN TIPO_INCIDENTE ti
    ON i.id_tipo_incidente = ti.id_tipo_incidente
GROUP BY
    t.id_tienda,
    t.nombre,
    ti.id_tipo_incidente,
    ti.nombre;
GO