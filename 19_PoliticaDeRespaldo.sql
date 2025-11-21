/*
-------------------------------------------------
--											   --
--			BASES DE DATOS APLICADA		       --
--											   --
-------------------------------------------------
-- GRUPO: 07                                   --
-- INTEGRANTES:								   --
-- Mendoza, Diego Emanuel			           --
-- Vazquez, Isaac Benjamin                     --
-- Pizarro Dorgan, Fabricio Alejandro          --
-- Piñero, Agustín                             --
-- Comerci Salcedo, Francisco Ivan             --
-------------------------------------------------
*/

/*  
   TITULO:       Politica de Respaldo y Recuperacion ante Desastres
   PROYECTO:     Sistema de Gestion de Consorcios (Com5900G07)
   
   VERSIÓN:      1.0
   FECHA:        10/11/2025
   AUTOR:        Grupo 07
   REVIEWER:     Gerencia de Altos de Saint Just
   ESTADO:       APROBADO PARA IMPLEMENTACION

   HISTORIAL DE CAMBIOS:
   --------------------------------------------------------------------------------
   Ver. | Fecha      | Autor       | Descripción
   --------------------------------------------------------------------------------
   1.0  | 10/11/2025 | Grupo 07    | Creacion inicial del documento. Definicion de
                                     RPO y Cronograma basado en analisis de
                                     transaccionalidad de SPs de Pagos.


===================================================================================

                                   CONTENIDO
                                   
   1. INTRODUCCION Y ALCANCE
   2. MODELO DE RECUPERACIÓN (RECOVERY MODEL)
   3. CRONOGRAMA DE RESPALDOS (SCHEDULE)
   4. PUNTO OBJETIVO DE RECUPERACIÓN (RPO)
   5. POLÍTICA SOBRE REPORTES GENERADOS

===================================================================================

1. INTRODUCCION Y ALCANCE
   ----------------------

   La presente politica tiene como objetivo garantizar la disponibilidad, integridad 
   y recuperacion de los datos criticos del Sistema de Gestion de Consorcios Altos de Saint Just.
   
   El alcance abarca:

   - Datos transaccionales de cobranzas. 
   - Datos maestros de consorcios y unidades funcionales.
   - Procedimientos almacenados críticos de reportes y APIs.

2. MODELO DE RECUPERACION (RECOVERY MODEL)
   ---------------------------------------
   Se establece que la base de datos operativa operara bajo el modelo: COMPLETA (FULL RECOVERY MODEL)
   
   Justificacion Tecnica:

   El sistema procesa transacciones monetarias. El modelo COMPLETO es mandatorio 
   ya que permite el respaldo del log de transacciones.
   Esto habilita la recuperacion en un punto exacto del tiempo (Point in Time),
   vital para deshacer errores logicos (ej: una ejecucion accidental de 
   eliminacion de estructuras o una importacion duplicada) sin perder 
   datos ingresados posteriormente.

3. CRONOGRAMA DE RESPALDOS (SCHEDULE)
   ----------------------------------

   Se implementara una estrategia de respaldo jerarquica (Full + Diferencial + Log) 
   para optimizar el almacenamiento y reducir el tiempo de restauracion (RTO).

    RESPALDO COMPLETO (Full Backup)

      - Frecuencia: Semanal.
      - Horario:    Domingos, 03:00 AM (Ventana de mantenimiento).
      - Retencion:  4 semanas en disco local. 1 año en almacenamiento en frío.
      - Objetivo:   Base solida de restauracion.

    RESPALDO DIFERENCIAL (Differential Backup)

      - Frecuencia: Diario.
      - Horario:    Lunes a Sabado, 03:00 AM.
      - Retencion:  1 semana (se sobrescribe al cerrar el ciclo semanal).
      - Objetivo:   Minimizar el tiempo de restauracion al consolidar los cambios diarios, evitando aplicar multiples logs secuenciales.

    RESPALDO DE LOG DE TRANSACCIONES

      - Frecuencia: Cada 1 Hora.
      - Horario:    De 08:00 AM a 20:00 PM (Horario comercial activo).
      - Retencion:  48 horas.
      - Objetivo:   Proteger las moviemientos. Mantiene el tamaño del archivo .ldf controlado.

4. PUNTO OBJETIVO DE RECUPERACION (RPO)
   ------------------------------------

   El Recovery Point Objective (RPO) definido para el negocio es de: 1 HORA.

   Analisis de Riesgo:

   Dada la frecuencia horaria de los backups del log de transacciones, la perdida 
   maxima tolerable ante una falla catastrofica del servidor es de 60 minutos 
   de informacion ingresada.
   
   Este riesgo es aceptable dado que:

   - El volumen de pagos por hora permite su reingreso manual.
   - Existen comprobantes externos (bancarios/mails) que respaldan las operaciones de esa ventana de tiempo perdida.

5. POLÍTICA SOBRE REPORTES GENERADOS
   ---------------------------------

   Los reportes de gestion son generados bajo demanda basandose en los datos transaccionales.
   
   Es por esto que la estrategia de respaldo de la Base de Datos cubre 
   la integridad de los reportes. Al asegurar los datos crudos (Tablas Pago y Gasto), 
   se asegura la capacidad de regenerar cualquier reporte historico o enviar 
   nuevamente las notificaciones a las APIs externas en caso de siniestro.

   5. POLÍTICA DE RESPALDO DE ARTEFACTOS Y REPORTES (FILE SYSTEM / STORAGE)
   ---------------------------------------------------------------------

   Los reportes generados constituyen documentos legales estaticos que no deben alterarse una vez emitidos.
   
   Utilizaremos la siguiente estrategia de respaldo de archivos:
   
    TIPO DE RESPALDO: Incremental Diario.

      - Horario: 23:30 PM (Cierre de operaciones).
      - Herramienta: Agente de Backup de Sistema Operativo o almacenamiento en la nube.
   
    RETENCION LEGAL

      - Reportes de Expensas, Flujo de Caja y Morosidad: 10 Años (segun Código Civil y Comercial).
      - Logs tecnicos: 3 meses.
   
    JUSTIFICACION

      A diferencia de la base de datos (que cambia constantemente), los reportes 
      son estaticos. Un backup diario es suficiente. 
      Separar el backup de archivos del backup de SQL optimiza el rendimiento y 
      asegura que, aunque se corrompa la base de datos, los documentos del cliente 
      permaneceran intactos.

*/
