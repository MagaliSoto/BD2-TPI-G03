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

