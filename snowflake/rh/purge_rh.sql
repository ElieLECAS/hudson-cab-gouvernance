-- =====================================================================
-- purge_rh.sql — règle R1 : supprimer les données d'un chauffeur 5 ans après la fin de son contrat, partout.
-- Source : contrat §5 (R1) ; guide, jour 3. À exécuter avec TRANSFORMER, propriétaire des tables.
-- Version « manuelle » : elle compte avant, purge, puis note chaque nombre dans une table temporaire de rapport.
-- La tâche T_PURGE (taches_rh.sql) répète les deux DELETE, sans le rapport.
-- Rejouable : une seconde exécution ne trouve plus rien à supprimer.
--
-- Choix (voir README) :
--  * le critère est end_date < aujourd'hui − 5 ans ; un chauffeur en poste (end_date vide) n'est jamais purgé ;
--  * R1 s'applique « partout où la donnée a été copiée » : on supprime aussi ses services dans RAW.DRIVER_SHIFTS.
--    Les services sont supprimés AVANT le chauffeur, car la liste des chauffeurs à purger se lit dans RAW.DRIVERS ;
--  * DIM_DRIVER et MART_DRIVER_MONTHLY ne se purgent pas à la main : on les reconstruit depuis RAW (INSERT OVERWRITE) ;
--  * les services d'un chauffeur inconnu (« orphelins ») ne sont pas touchés : R1 ne les concerne pas, la règle
--    de qualité service_rattache les mesure ;
--  * la purge doit tourner APRÈS chaque chargement : un fichier complet rechargé ramène les anciens chauffeurs
--    dans RAW, que la purge supprime de nouveau. D'où la tâche quotidienne.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- Le rapport : une table temporaire (elle disparaît à la fin de la session, rien n'est conservé)
CREATE OR REPLACE TEMPORARY TABLE NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (
    ordre NUMBER AUTOINCREMENT, etape VARCHAR, valeur VARCHAR);

-- La date limite : un chauffeur dont le contrat a pris fin avant cette date est à purger
SET limite = (SELECT DATEADD(year, -5, CURRENT_DATE()));
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'Date limite : fin de contrat avant le', $limite::VARCHAR;

-- 1. Compter AVANT
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'RAW.DRIVERS avant', COUNT(*)::VARCHAR FROM NYC_TAXI.RAW.DRIVERS;
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'Chauffeurs à purger', COUNT(*)::VARCHAR FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < $limite;
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'RAW.DRIVER_SHIFTS avant', COUNT(*)::VARCHAR FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'Services de ces chauffeurs', COUNT(*)::VARCHAR FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < $limite);

-- 2. Purger : les services d'abord, puis les chauffeurs
DELETE FROM NYC_TAXI.RAW.DRIVER_SHIFTS
 WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < $limite);
DELETE FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < $limite;

-- On garde l'identifiant de cette dernière requête : le Time Travel permet de lire la table « juste avant » elle
-- (preuves_purge.sql). Il faut le faire avant de fixer la rétention (conservation_rh.sql).
SET qid_purge = LAST_QUERY_ID();

-- 3. Compter APRÈS
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'RAW.DRIVERS après', COUNT(*)::VARCHAR FROM NYC_TAXI.RAW.DRIVERS;
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'RAW.DRIVER_SHIFTS après', COUNT(*)::VARCHAR FROM NYC_TAXI.RAW.DRIVER_SHIFTS;

-- Le rapport de la purge. Attendu : 7 lignes (400 avant, 46 à purger, 0 service concerné, 354 après).
SELECT etape, valeur FROM NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION ORDER BY ordre;

-- À enchaîner ensuite (dans la même session, pour garder $qid_purge et le rapport) :
--   rh/marts/dim_driver.sql, rh/marts/mart_driver_monthly.sql (reconstruction), preuves_purge.sql, conservation_rh.sql.
