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