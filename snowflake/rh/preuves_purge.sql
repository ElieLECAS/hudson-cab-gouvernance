-- =====================================================================
-- preuves_purge.sql — à lancer juste après la purge et la reconstruction de DIM_DRIVER et du mart.
-- Dans la même session que purge_rh.sql (il lit $qid_purge et la table de rapport). Rôle TRANSFORMER.
-- 1. Les tables reconstruites ont perdu les chauffeurs purgés.
-- 2. Preuve du Time Travel : une ligne supprimée est encore lisible tant que la rétention n'est pas réduite.
--    C'est le risque que la règle R2 traite : conservation_rh.sql fixe la rétention à 1 jour.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'DIM_DRIVER après reconstruction', COUNT(*)::VARCHAR FROM NYC_TAXI.MARTS.DIM_DRIVER;
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'MART_DRIVER_MONTHLY après reconstruction', COUNT(*)::VARCHAR FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;

-- Time Travel : l'état de RAW.DRIVERS juste avant la requête de purge (BEFORE STATEMENT)
SET sql_tt1 = 'INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur) '
  || 'SELECT ''Time Travel : RAW.DRIVERS juste avant la purge'', COUNT(*)::VARCHAR '
  || 'FROM NYC_TAXI.RAW.DRIVERS BEFORE(STATEMENT => ''' || $qid_purge || ''')';
EXECUTE IMMEDIATE $sql_tt1;

SET sql_tt2 = 'INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur) '
  || 'SELECT ''Time Travel : chauffeurs purgés encore lisibles'', COUNT(*)::VARCHAR '
  || 'FROM NYC_TAXI.RAW.DRIVERS BEFORE(STATEMENT => ''' || $qid_purge || ''') '
  || 'WHERE end_date < DATEADD(year, -5, CURRENT_DATE())';
EXECUTE IMMEDIATE $sql_tt2;
