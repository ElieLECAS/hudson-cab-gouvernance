-- =====================================================================
-- taches_rh.sql — le graphe de tâches quotidien : T_PURGE → T_QUALITE → T_TABLES.
-- Source : contrat §1 (tâches) et §6 (qualité) ; guide, jour 3 ; modèle : exemples/05. Rôle TRANSFORMER.
-- Rejouable : on suspend la racine, on recrée les trois tâches, on les réactive et on les lance.
-- L'ordre qui protège : on PURGE (R1), on CONTRÔLE (qualité), et on ne RECONSTRUIT les tables que si le contrôle est passé.
--  * T_PURGE (racine) : horaire quotidien, 6 h heure de Paris ; les deux DELETE de purge_rh.sql ;
--  * T_QUALITE : après T_PURGE ; mesure les 8 règles (rh/controles/), enregistre une ligne par règle dans
--    GOUVERNANCE.QUALITE_RESULTATS (OK/ALERTE), PUIS lève une erreur si service_rattache dépasse son seuil (bloquante) :
--    la tâche échoue et T_TABLES ne part pas ;
--  * T_TABLES : après T_QUALITE ; les trois INSERT OVERWRITE de rh/marts/, sans USE ROLE ni USE WAREHOUSE.
-- Une tâche tourne avec les droits de son propriétaire (TRANSFORMER) : elle lit en clair et figure dans ACCES_DEPOT.
-- Une tâche activée consomme des crédits chaque jour : suspendre la racine à la fin (ALTER TASK … SUSPEND).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- Modifier un graphe : suspendre d'abord la racine (sans erreur si elle n'existe pas encore)
ALTER TASK IF EXISTS NYC_TAXI.MARTS.T_PURGE SUSPEND;

CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_PURGE
  WAREHOUSE = NYC_TAXI_WH
  SCHEDULE = 'USING CRON 0 6 * * * Europe/Paris'
  COMMENT = 'R1 : supprime les chauffeurs dont le contrat a pris fin il y a plus de 5 ans, et leurs services. Racine du graphe.'
AS
EXECUTE IMMEDIATE $$
BEGIN
  DELETE FROM NYC_TAXI.RAW.DRIVER_SHIFTS
   WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < DATEADD(year, -5, CURRENT_DATE()));
  DELETE FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < DATEADD(year, -5, CURRENT_DATE());
  RETURN 'Purge faite';
END;
$$;

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
  SELECT (50)::NUMBER(18,2) INTO :seuil;
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

CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_TABLES
  WAREHOUSE = NYC_TAXI_WH
  COMMENT = 'Reconstruit DIM_DEPOT, DIM_DRIVER et MART_DRIVER_MONTHLY par INSERT OVERWRITE, seulement si le contrôle est passé.'
  AFTER NYC_TAXI.MARTS.T_QUALITE
AS
EXECUTE IMMEDIATE $$
BEGIN
  INSERT OVERWRITE INTO NYC_TAXI.MARTS.DIM_DEPOT (depot, quartier, ouvert_en, nb_places) VALUES
      ('Bronx',    'Hunts Point',       2009, 140),
      ('Brooklyn', 'East New York',     2011, 120),
      ('Queens',   'Long Island City',  2008, 180);
  INSERT OVERWRITE INTO NYC_TAXI.MARTS.DIM_DRIVER
  SELECT
      driver_id,
      first_name,
      last_name,
      email,
      phone,
      birth_date,
      tlc_license_number,
      depot,
      hire_date,
      end_date,
      end_date IS NULL                                                          AS is_active,
      ROUND(DATEDIFF(day, hire_date, COALESCE(end_date, CURRENT_DATE())) / 365.25, 1) AS tenure_years
  FROM NYC_TAXI.STAGING.STG_RH__DRIVERS;
  INSERT OVERWRITE INTO NYC_TAXI.MARTS.MART_DRIVER_MONTHLY
  SELECT
      DATE_TRUNC('month', s.shift_date)::date     AS activity_month,
      s.driver_id,
      d.first_name || ' ' || d.last_name          AS driver_name,
      s.depot,
      COUNT(*)                                    AS nb_shifts,
      ROUND(SUM(s.hours_worked), 1)               AS hours_worked,
      SUM(s.trips_count)                          AS trips_count,
      ROUND(SUM(s.revenue_usd), 2)                AS revenue_usd
  FROM NYC_TAXI.STAGING.STG_RH__DRIVER_SHIFTS s
  LEFT JOIN NYC_TAXI.MARTS.DIM_DRIVER d ON d.driver_id = s.driver_id
  GROUP BY 1, 2, 3, 4;
  RETURN 'Tables reconstruites';
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
