-- =====================================================================
-- 00_toutes_les_regles.sql — les huit règles de qualité du contrat (§6), mesurées en une seule requête.
-- À exécuter avec TRANSFORMER. Lecture seule : ne modifie rien (la tâche T_QUALITE, elle, enregistre
-- chaque mesure dans GOUVERNANCE.QUALITE_RESULTATS). Le statut vaut OK quand nb_anomalies <= seuil, ALERTE sinon.
-- Les huit SELECT sont ceux des fichiers de ce dossier (licence_unique.sql est fourni par le kit).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

SELECT regle, nb_anomalies, seuil, IFF(nb_anomalies <= seuil, 'OK', 'ALERTE') AS statut, gravite
FROM (
  SELECT 'licence_unique' AS regle, nb_anomalies, (0)::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT COUNT(*) - COUNT(DISTINCT tlc_license_number) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
  )
  UNION ALL
  SELECT 'telephone_renseigne' AS regle, nb_anomalies, (CEIL(0.05 * (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS WHERE end_date IS NULL)))::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT COUNT_IF(phone IS NULL OR TRIM(phone) = '') AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
    WHERE end_date IS NULL
  )
  UNION ALL
  SELECT 'email_valide' AS regle, nb_anomalies, (0)::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT COUNT_IF(email IS NULL OR email NOT LIKE '%@%') AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
  )
  UNION ALL
  SELECT 'dates_coherentes' AS regle, nb_anomalies, (0)::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT COUNT_IF(hire_date > CURRENT_DATE() OR end_date < hire_date) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
  )
  UNION ALL
  SELECT 'depot_connu' AS regle, nb_anomalies, (0)::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVERS)
         + (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVER_SHIFTS) AS nb_anomalies
  )
  UNION ALL
  SELECT 'service_rattache' AS regle, nb_anomalies, (50)::NUMBER(18,2) AS seuil, 'bloquant' AS gravite
  FROM (
    SELECT COUNT(*) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
    WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id)
  )
  UNION ALL
  SELECT 'service_unique' AS regle, nb_anomalies, (0)::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT COUNT(*) - COUNT(DISTINCT shift_id) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  )
  UNION ALL
  SELECT 'duree_plausible' AS regle, nb_anomalies, (0)::NUMBER(18,2) AS seuil, 'avertissement' AS gravite
  FROM (
    SELECT COUNT_IF(hours_worked > 16) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  )
)
ORDER BY regle;
