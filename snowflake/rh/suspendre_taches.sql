-- =====================================================================
-- suspendre_taches.sql — arrêter le graphe de tâches à la fin du projet. Rôle TRANSFORMER.
-- Une tâche activée tourne chaque jour et consomme des crédits : on suspend la racine, puis les deux autres
-- (une tâche enfant ne se suspend que lorsque la racine l'est déjà). Rejouable.
-- Pour les réactiver : SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('NYC_TAXI.MARTS.T_PURGE'); (ou rejouer taches_rh.sql).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

ALTER TASK NYC_TAXI.MARTS.T_PURGE   SUSPEND;
ALTER TASK NYC_TAXI.MARTS.T_QUALITE SUSPEND;
ALTER TASK NYC_TAXI.MARTS.T_TABLES  SUSPEND;

-- Vérifier : les trois tâches ont l'état « suspended ».
SHOW TASKS IN SCHEMA NYC_TAXI.MARTS;
