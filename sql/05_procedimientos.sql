/* =====================================================================
   TPI Base de Datos II - Equipo 03
   05 - Procedimientos almacenados
   Responsable: Evelyn Baini
   ---------------------------------------------------------------------
   A completar:
   - sp_reporte_detecciones(@id_tienda, @desde, @hasta, @confianza_min)
   - sp_registrar_incidente(...): valida acceso vigente del usuario a la
     tienda en USUARIO_TIENDA (fecha_hasta NULL), crea persona si no
     existe, incidente, PERSONA_INCIDENTE y VETO (con id_incidente).
     Transacción + TRY/CATCH.
   ===================================================================== */

USE BD2_TPI_G03;
GO

