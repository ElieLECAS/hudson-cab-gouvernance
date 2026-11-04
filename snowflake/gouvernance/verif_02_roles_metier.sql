-- =====================================================================
-- verif_02_roles_metier.sql — contrôle des droits donnés par 02_roles_metier.sql, pour les quatre rôles en une fois.
-- À exécuter en entier avec ACCOUNTADMIN (Ctrl+Maj+Entrée). Ne modifie aucun droit : il lit, et range le résultat
-- de chaque SHOW dans une table TEMPORAIRE (elle disparaît à la fin de la session).
-- Les droits « futurs » n'apparaissent pas dans SHOW GRANTS : ils ont leur propre commande, SHOW FUTURE GRANTS.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;

CREATE OR REPLACE TEMPORARY TABLE NYC_TAXI.PUBLIC.TMP_VERIF_DROITS (
    role_name VARCHAR, portee VARCHAR, privilege VARCHAR, sur VARCHAR, nom VARCHAR);

-- Droits actuels de chaque rôle
SHOW GRANTS TO ROLE RH_PAIE;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'RH_PAIE', 'actuel', "privilege", "granted_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
SHOW GRANTS TO ROLE RESP_DEPOT_QUEENS;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'RESP_DEPOT_QUEENS', 'actuel', "privilege", "granted_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
SHOW GRANTS TO ROLE RESP_DEPOT_BRONX;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'RESP_DEPOT_BRONX', 'actuel', "privilege", "granted_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
SHOW GRANTS TO ROLE ANALYSTE;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'ANALYSTE', 'actuel', "privilege", "granted_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Droits futurs de chaque rôle
SHOW FUTURE GRANTS TO ROLE RH_PAIE;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'RH_PAIE', 'futur', "privilege", "grant_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
SHOW FUTURE GRANTS TO ROLE RESP_DEPOT_QUEENS;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'RESP_DEPOT_QUEENS', 'futur', "privilege", "grant_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
SHOW FUTURE GRANTS TO ROLE RESP_DEPOT_BRONX;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'RESP_DEPOT_BRONX', 'futur', "privilege", "grant_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
SHOW FUTURE GRANTS TO ROLE ANALYSTE;
INSERT INTO NYC_TAXI.PUBLIC.TMP_VERIF_DROITS SELECT 'ANALYSTE', 'futur', "privilege", "grant_on", "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Vérifier. Attendu :
--   chaque rôle : 7 droits actuels ;
--   droits futurs : 2 pour ANALYSTE (tables futures de MARTS, vues futures de GOUVERNANCE), 1 pour chacun des trois autres ;
--   sur_raw_ou_staging = 0 partout (aucun droit sur RAW ni STAGING).
SELECT role_name, portee, COUNT(*) AS nb_droits,
       COUNT_IF(nom ILIKE '%.RAW%' OR nom ILIKE '%STAGING%') AS sur_raw_ou_staging
FROM NYC_TAXI.PUBLIC.TMP_VERIF_DROITS
GROUP BY role_name, portee
ORDER BY role_name, portee;
