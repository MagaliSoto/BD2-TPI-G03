/* =====================================================================
   TPI Base de Datos II - Equipo 03
   06 - Triggers
   Responsable: Cristian Tesaglio
   ---------------------------------------------------------------------
   A completar:
   - INSERT en VETO: rechaza si ya hay veto vigente que se superpone
     y registra ALTA en HISTORIAL_VETO (datos en JSON con FOR JSON PATH).
   - INSERT en EVENTO_DETECCION: si no hay veto vigente para esa persona
     en esa tienda o la confianza es baja -> DESCARTADO con fecha_revision.
   - INSTEAD OF DELETE en VETO: estado LEVANTADO + fecha_fin = hoy, BAJA.
   - UPDATE en VETO (bonus): MODIF con datos anteriores y nuevos.
   ===================================================================== */

USE BD2_TPI_G03;
GO

