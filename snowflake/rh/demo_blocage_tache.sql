-- =====================================================================
-- demo_blocage_tache.sql — prouver que la règle bloquante arrête le graphe. Rôle TRANSFORMER.
-- On recrée T_QUALITE avec un seuil de 10 au lieu de 50 pour service_rattache (le fichier compte 25 services
-- sans chauffeur connu) : T_QUALITE enregistre ses huit mesures (service_rattache en ALERTE), puis échoue
-- (FAILED) ; T_TABLES ne part pas. Pour revenir à la normale, rejouer taches_rh.sql (seuil 50).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

ALTER TASK IF EXISTS NYC_TAXI.MARTS.T_PURGE SUSPEND;

CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_QUALITE
  WAREHOUSE = NYC_TAXI_WH
  COMMENT = 'Mesure les 8 règles de qualité sur RAW, enregistre chaque résultat, puis s''arrête si service_rattache dépasse son seuil.'
  AFTER NYC_TAXI.MARTS.T_PURGE
AS
EXECUTE IMMEDIATE $$
DECLARE
  nb             NUMBER;
  seuil          NUMBER(18,2);
  bloquant_nb    NUMBER DEFAULT 0;
  bloquant_seuil NUMBER(18,2) DEFAULT 0;
  bloquee        EXCEPTION (-20001, 'Règle bloquante service_rattache en dépassement');
BEGIN
  -- licence_unique (avertissement) : un numéro de licence TLC n’appartient qu’à un seul chauffeur
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT(*) - COUNT(DISTINCT tlc_license_number) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
  );
  SELECT (0)::NUMBER(18,2) INTO :seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'licence_unique', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- telephone_renseigne (avertissement) : chaque chauffeur en poste a un numéro de téléphone
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT_IF(phone IS NULL OR TRIM(phone) = '') AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
    WHERE end_date IS NULL
  );
  SELECT CEIL(0.05 * COUNT(*))::NUMBER(18,2) INTO :seuil FROM NYC_TAXI.RAW.DRIVERS WHERE end_date IS NULL;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'telephone_renseigne', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- email_valide (avertissement) : l’adresse e-mail d’un chauffeur contient un @
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT_IF(email IS NULL OR email NOT LIKE '%@%') AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
  );
  SELECT (0)::NUMBER(18,2) INTO :seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'email_valide', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- dates_coherentes (avertissement) : pas d’embauche dans le futur, pas de fin de contrat avant l’embauche
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT_IF(hire_date > CURRENT_DATE() OR end_date < hire_date) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVERS
  );
  SELECT (0)::NUMBER(18,2) INTO :seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'dates_coherentes', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- depot_connu (avertissement) : le dépôt est écrit exactement Bronx, Brooklyn ou Queens (chauffeurs et services)
  SELECT nb_anomalies INTO :nb FROM (
    SELECT (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVERS)
         + (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVER_SHIFTS) AS nb_anomalies
  );
  SELECT (0)::NUMBER(18,2) INTO :seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'depot_connu', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- service_rattache (bloquant) : chaque service appartient à un chauffeur connu
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT(*) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
    WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id)
  );
  SELECT (10)::NUMBER(18,2) INTO :seuil;
  bloquant_nb := nb;
  bloquant_seuil := seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'service_rattache', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- service_unique (avertissement) : un identifiant de service n’apparaît qu’une fois
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT(*) - COUNT(DISTINCT shift_id) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  );
  SELECT (0)::NUMBER(18,2) INTO :seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'service_unique', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');

  -- duree_plausible (avertissement) : un service ne dure pas plus de 16 heures
  SELECT nb_anomalies INTO :nb FROM (
    SELECT COUNT_IF(hours_worked > 16) AS nb_anomalies
    FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  );
  SELECT (0)::NUMBER(18,2) INTO :seuil;
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'duree_plausible', CURRENT_TIMESTAMP()::TIMESTAMP_NTZ, :nb, :seuil, IFF(:nb <= :seuil, 'OK', 'ALERTE');
  -- Les huit résultats sont enregistrés AVANT : même quand la tâche s’arrête, la trace reste.
  IF (bloquant_nb > bloquant_seuil) THEN
    RAISE bloquee;
  END IF;
  RETURN 'Qualité mesurée';
END;
$$;

-- Activer la racine ET les tâches qui en dépendent (sinon les suivantes ne partent pas), puis lancer sans attendre 6 h.
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('NYC_TAXI.MARTS.T_PURGE');
EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;

-- Laisser le graphe tourner (les trois tâches se suivent), puis lire ce qui s'est passé.
CALL SYSTEM$WAIT(90);

-- Le résultat : l'état de chaque tâche (TASK_HISTORY) et les huit dernières mesures de qualité (QUALITE_RESULTATS).
SELECT type, nom, etat, detail, quand FROM (
    SELECT 'tâche' AS type, name AS nom, state AS etat, COALESCE(LEFT(error_message, 300), '') AS detail, query_start_time::TIMESTAMP_NTZ AS quand
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TASK_HISTORY(RESULT_LIMIT => 30))
    WHERE name IN ('T_PURGE', 'T_QUALITE', 'T_TABLES') AND state <> 'SCHEDULED'
    ORDER BY query_start_time DESC LIMIT 6
)
UNION ALL
SELECT type, nom, etat, detail, quand FROM (
    SELECT 'règle' AS type, regle AS nom, statut AS etat, nb_anomalies::VARCHAR || ' anomalies, seuil ' || seuil::VARCHAR AS detail, mesure_le AS quand
    FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS
    ORDER BY mesure_le DESC, regle LIMIT 8
)
ORDER BY type DESC, quand, nom;
