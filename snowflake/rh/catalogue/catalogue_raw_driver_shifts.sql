-- =====================================================================
-- catalogue_raw_driver_shifts.sql — fiche de catalogue COURTE de NYC_TAXI.RAW.DRIVER_SHIFTS.
-- À exécuter avec TRANSFORMER, propriétaire de la table. Rejouable : COMMENT et SET TAG remplacent la valeur.
-- Les colonnes d'activité (heures, courses, recette) ne sont pas personnelles en elles-mêmes, mais elles le
-- deviennent par driver_id : seul driver_id porte le tag DONNEE_PERSONNELLE (voir REGISTRE.md).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.RAW.DRIVER_SHIFTS IS
  'Copie fidèle du fichier RH driver_shifts.csv : 1 ligne = 1 service d''un chauffeur (date, dépôt, horaires, courses, recette), sans correction. Le fichier contient des doublons d''identifiant de service, des services rattachés à un chauffeur inconnu et des durées irréalistes : ils sont mesurés par les règles de qualité et les doublons sont écartés dans STAGING. Chargée par COPY INTO depuis RH_STAGE (fichier retiré ensuite, règle R3). Responsable du traitement : Hudson Cab Europe (Paris) ; propriétaire technique : équipe data.';

-- 2. Les colonnes (descriptions brèves)
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.shift_id IS
  'Identifiant du service. Doit être unique ; un identifiant répété est une anomalie (règle de qualité service_unique).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.driver_id IS
  'Identifiant interne du chauffeur qui a fait le service (pseudonyme). Doit exister dans DRIVERS (règle de qualité service_rattache). Rend personnelles toutes les mesures du service.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.shift_date IS
  'Date du service.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.depot IS
  'Dépôt où le service a été fait : Bronx, Brooklyn ou Queens. Les valeurs du fichier actuel sont propres ; STAGING normalise quand même l''écriture (majuscules, espaces) par précaution.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.start_hour IS
  'Heure de début du service, de 0 à 23.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.hours_worked IS
  'Durée du service en heures. Plus de 16 heures est une anomalie (règle de qualité duree_plausible).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.trips_count IS
  'Nombre de courses effectuées pendant le service.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.revenue_usd IS
  'Recette du service, en dollars américains.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS._source_file IS
  'Colonne technique : nom du fichier d''où vient la ligne, relevé par le chargement. Ne décrit aucune personne.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS._loaded_at IS
  'Colonne technique : date et heure (sans fuseau) du chargement de la ligne dans RAW. Départage les doublons de shift_id dans STAGING. Ne décrit aucune personne.';

-- 3. Les deux tags de table. La règle R1 s'applique aussi à cette table : les services d'un chauffeur
--    sont supprimés 5 ans après la fin de son contrat.
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur';

-- 4. DONNEE_PERSONNELLE : le pseudonyme seulement
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS MODIFY COLUMN driver_id SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';

-- 5. Vérifier : 1 colonne (driver_id)
SELECT column_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVER_SHIFTS', 'table'))
WHERE tag_name = 'DONNEE_PERSONNELLE'
ORDER BY column_name;
