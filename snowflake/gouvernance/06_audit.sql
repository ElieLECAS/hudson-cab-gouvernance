-- =====================================================================
-- 06_audit.sql — qui a lu DIM_DRIVER ? Requête d'audit sur les 7 derniers jours.
-- Source : guide, jour 3 (audit). À exécuter avec ACCOUNTADMIN (Ctrl+Maj+Entrée). Lecture seule.
-- ACCESS_HISTORY (Enterprise) dit QUELS OBJETS et QUELLES COLONNES une requête a lus, mais pas avec quel rôle :
-- le rôle vient de QUERY_HISTORY, joint sur query_id. Les deux vues de SNOWFLAKE.ACCOUNT_USAGE ont un retard
-- (jusqu'à 3 h pour ACCESS_HISTORY) : une requête de la dernière heure peut ne pas encore y figurer.
-- Seules les requêtes qui ont réussi y sont : un accès refusé (comme celui de GOUVERNANCE sur DIM_DRIVER) n'y est pas.
-- Une requête qui lit une table en passant par une politique est comptée, même si elle renvoie 0 ligne (ACCOUNTADMIN).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;

SELECT
    qh.role_name                                             AS role,
    ah.user_name                                             AS utilisateur,
    COUNT(DISTINCT ah.query_id)                              AS nb_requetes,
    COUNT(DISTINCT c.value:columnName::STRING)               AS nb_colonnes_lues,
    MIN(ah.query_start_time)::TIMESTAMP_NTZ                  AS premiere_lecture,
    MAX(ah.query_start_time)::TIMESTAMP_NTZ                  AS derniere_lecture
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
  ON qh.query_id = ah.query_id
, LATERAL FLATTEN(INPUT => ah.base_objects_accessed) o
, LATERAL FLATTEN(INPUT => o.value:columns, OUTER => TRUE) c
WHERE o.value:objectName::STRING = 'NYC_TAXI.MARTS.DIM_DRIVER'
  AND ah.query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY qh.role_name, ah.user_name
ORDER BY nb_requetes DESC;

-- Bonus (à lancer seul) : les colonnes personnelles lues, par rôle
--   SELECT qh.role_name AS role, c.value:columnName::STRING AS colonne, COUNT(DISTINCT ah.query_id) AS nb_requetes
--   FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
--   JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh ON qh.query_id = ah.query_id
--   , LATERAL FLATTEN(INPUT => ah.base_objects_accessed) o
--   , LATERAL FLATTEN(INPUT => o.value:columns) c
--   WHERE o.value:objectName::STRING = 'NYC_TAXI.MARTS.DIM_DRIVER'
--     AND c.value:columnName::STRING IN ('EMAIL', 'PHONE', 'FIRST_NAME', 'LAST_NAME', 'BIRTH_DATE', 'TLC_LICENSE_NUMBER')
--     AND ah.query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
--   GROUP BY 1, 2 ORDER BY 1, 2;
