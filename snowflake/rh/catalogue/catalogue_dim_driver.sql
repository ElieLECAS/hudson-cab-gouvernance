-- =====================================================================
-- catalogue_dim_driver.sql — fiche de catalogue COMPLÈTE de NYC_TAXI.MARTS.DIM_DRIVER.
-- À exécuter avec TRANSFORMER, propriétaire de la table (il a reçu APPLY sur les 3 tags dans 01_gouvernance.sql).
-- Rejouable : COMMENT et SET TAG remplacent la valeur précédente. Une table recréée (CREATE OR REPLACE)
-- perdrait tout ceci : DIM_DRIVER se remplit par INSERT OVERWRITE pour ne jamais être recréée.
-- Choix des tags : docs/REGISTRE.md partie 1 (verdict colonne par colonne) ; valeurs : contrat §3.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table : ce qu'elle contient, d'où elle vient, à quel rythme elle change, qui en répond
COMMENT ON TABLE NYC_TAXI.MARTS.DIM_DRIVER IS
  'Dimension chauffeur : 1 ligne = 1 chauffeur de Hudson Cab Partners, en poste ou parti. Source : fichier RH drivers.csv, via NYC_TAXI.RAW.DRIVERS puis la vue STAGING.STG_RH__DRIVERS. Reconstruite par INSERT OVERWRITE à chaque exécution des tâches (T_TABLES) ; les chauffeurs partis depuis plus de 5 ans en sont retirés par la purge. Responsable du traitement : Hudson Cab Europe (Paris) ; propriétaire technique : équipe data (rôle TRANSFORMER).';

-- 2. Chaque colonne : sa signification, pas son nom répété
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.driver_id IS
  'Identifiant interne du chauffeur (par exemple D0001), clé de la table. Pseudonyme : il ne nomme personne seul mais relie un chauffeur à tous ses services. Visible de tous les rôles métier, pour compter et joindre sans nommer.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.first_name IS
  'Prénom du chauffeur, tel que saisi dans le fichier RH.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.last_name IS
  'Nom de famille du chauffeur, tel que saisi dans le fichier RH.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.email IS
  'Adresse e-mail du chauffeur, en minuscules et sans espace superflu (nettoyée dans STAGING). Une valeur sans @ est une anomalie, mesurée par la règle de qualité email_valide.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.phone IS
  'Numéro de téléphone du chauffeur. Vide (NULL) = non renseigné ; la règle telephone_renseigne tolère 5 % de chauffeurs en poste sans numéro.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.birth_date IS
  'Date de naissance complète du chauffeur. Seule l''année est destinée à l''analyse (rôle ANALYSTE).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.tlc_license_number IS
  'Numéro de licence de la TLC (Taxi and Limousine Commission de New York), délivré à une personne et unique. Un numéro partagé par deux chauffeurs est une anomalie, mesurée par la règle licence_unique.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.depot IS
  'Dépôt de rattachement : Bronx, Brooklyn ou Queens. Écriture normalisée dans STAGING (majuscules, espaces retirés). Sert à filtrer les lignes visibles par les responsables de dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.hire_date IS
  'Date d''embauche. Une date dans le futur est une anomalie, mesurée par la règle dates_coherentes.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.end_date IS
  'Date de fin de contrat. Vide = chauffeur en poste. Sert à calculer l''échéance de conservation : suppression 5 ans après cette date (règle R1).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.is_active IS
  'Colonne calculée : vrai quand end_date est vide (chauffeur en poste), faux sinon. Elle révèle indirectement si le contrat est terminé.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.tenure_years IS
  'Colonne calculée : ancienneté en années (une décimale), de hire_date à end_date, ou à aujourd''hui pour un chauffeur en poste. Recalculée à chaque exécution.';

-- 3. Les tags de la table : sensibilité et durée de conservation (les colonnes en héritent)
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat';

-- 4. Le tag DONNEE_PERSONNELLE : sur chaque colonne qui décrit une personne (jamais sur la table :
--    il serait hérité par toutes les colonnes). hire_date, end_date, depot, is_active et tenure_years n'ont
--    aucune valeur adaptée dans la liste du contrat (voir REGISTRE.md) : elles restent sans ce tag.
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN driver_id          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN first_name         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN last_name          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN email              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'email';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN phone              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'telephone';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN birth_date         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'date_naissance';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN tlc_license_number SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_officiel';

-- 5. Vérifier : 7 colonnes portent DONNEE_PERSONNELLE
SELECT column_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
WHERE tag_name = 'DONNEE_PERSONNELLE'
ORDER BY column_name;

-- À lancer ensuite, seule : aucune colonne sans description (0 ligne attendue)
--   SELECT column_name FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
--   WHERE table_schema = 'MARTS' AND table_name = 'DIM_DRIVER' AND comment IS NULL;
