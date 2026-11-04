-- =====================================================================
-- conservation_rh.sql — règles R2 et R3.
-- R2 : une donnée personnelle supprimée ne doit plus pouvoir être restaurée par Time Travel au-delà de 1 jour.
--      On fixe DATA_RETENTION_TIME_IN_DAYS = 1 sur chaque table qui contient des données de chauffeurs.
--      Seul le propriétaire (TRANSFORMER) peut le régler. Le Fail-safe de 7 jours, lui, n'est pas réglable :
--      une donnée supprimée n'a réellement disparu qu'au bout de 1 + 7 = 8 jours (à signaler dans le registre).
-- R3 : le fichier RH ne reste pas sur le stage une fois chargé (PURGE = TRUE au chargement) : on le vérifie.
-- À exécuter avec TRANSFORMER, APRÈS preuves_purge.sql (le Time Travel doit être prouvé avant de réduire la rétention).
-- Rejouable. Le rapport final lit la table temporaire créée par purge_rh.sql (créée ici si elle n'existe pas).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

CREATE TEMPORARY TABLE IF NOT EXISTS NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (
    ordre NUMBER AUTOINCREMENT, etape VARCHAR, valeur VARCHAR);

-- Rétention AVANT
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'R2 rétention avant : ' || table_schema || '.' || table_name, retention_time::VARCHAR
  FROM NYC_TAXI.INFORMATION_SCHEMA.TABLES
  WHERE (table_schema, table_name) IN (('RAW', 'DRIVERS'), ('RAW', 'DRIVER_SHIFTS'),
                                      ('MARTS', 'DIM_DRIVER'), ('MARTS', 'MART_DRIVER_MONTHLY'))
  ORDER BY table_schema, table_name;

-- R2 : les quatre tables qui contiennent des données de chauffeurs
ALTER TABLE NYC_TAXI.RAW.DRIVERS               SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS         SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER          SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY SET DATA_RETENTION_TIME_IN_DAYS = 1;

-- Rétention APRÈS
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'R2 rétention après : ' || table_schema || '.' || table_name, retention_time::VARCHAR
  FROM NYC_TAXI.INFORMATION_SCHEMA.TABLES
  WHERE (table_schema, table_name) IN (('RAW', 'DRIVERS'), ('RAW', 'DRIVER_SHIFTS'),
                                      ('MARTS', 'DIM_DRIVER'), ('MARTS', 'MART_DRIVER_MONTHLY'))
  ORDER BY table_schema, table_name;

-- R3 : aucun fichier sur le stage (la table de répertoire se rafraîchit avant d'être lue)
ALTER STAGE NYC_TAXI.RAW.RH_STAGE REFRESH;
INSERT INTO NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION (etape, valeur)
  SELECT 'R3 fichiers restés sur RH_STAGE', COUNT(*)::VARCHAR FROM DIRECTORY(@NYC_TAXI.RAW.RH_STAGE);

-- Le rapport. Attendu : retention après = 1 pour les quatre tables, et 0 fichier sur le stage.
SELECT etape, valeur FROM NYC_TAXI.RAW.TMP_RAPPORT_CONSERVATION ORDER BY ordre;
