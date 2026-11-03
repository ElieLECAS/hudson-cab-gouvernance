-- =====================================================================
-- catalogue_raw_drivers.sql — fiche de catalogue COMPLÈTE de NYC_TAXI.RAW.DRIVERS.
-- À exécuter avec TRANSFORMER, propriétaire de la table. Rejouable : COMMENT et SET TAG remplacent la valeur.
-- RAW est une copie fidèle du fichier : les erreurs du fichier y sont conservées (elles sont mesurées par
-- les règles de qualité, qui lisent RAW). Les vues de STAGING ne se cataloguent pas : elles lisent RAW, et
-- ce qui protège les colonnes de RAW s'applique aussi à elles.
-- Choix des tags : docs/REGISTRE.md partie 1 ; valeurs : contrat §3.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.RAW.DRIVERS IS
  'Copie fidèle du fichier RH drivers.csv : 1 ligne = 1 chauffeur du fichier, sans aucune correction (dépôts mal écrits, e-mails sans @ et dates incohérentes y sont conservés). Chargée par COPY INTO depuis le stage RH_STAGE ; le fichier est retiré du stage une fois copié (règle R3). Lue par le rôle des outils (TRANSFORMER) seulement. Responsable du traitement : Hudson Cab Europe (Paris) ; propriétaire technique : équipe data.';

-- 2. Chaque colonne
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.driver_id IS
  'Identifiant interne du chauffeur (par exemple D0001), tel qu''il figure dans le fichier. Pseudonyme : il relie un chauffeur à ses services sans le nommer.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.first_name IS
  'Prénom du chauffeur, tel que saisi dans le fichier RH.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.last_name IS
  'Nom de famille du chauffeur, tel que saisi dans le fichier RH.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.email IS
  'Adresse e-mail du chauffeur, telle qu''elle est écrite dans le fichier : majuscules et espaces conservés, valeur sans @ possible (règle de qualité email_valide).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.phone IS
  'Numéro de téléphone du chauffeur, tel qu''il est écrit dans le fichier. Vide = non renseigné (règle de qualité telephone_renseigne).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.birth_date IS
  'Date de naissance complète du chauffeur.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.tlc_license_number IS
  'Numéro de licence de la TLC (Taxi and Limousine Commission de New York), délivré à une personne. Un numéro partagé par deux chauffeurs est une anomalie (règle licence_unique).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.depot IS
  'Dépôt de rattachement, tel qu''il est écrit dans le fichier : Bronx, Brooklyn ou Queens attendus, mais le fichier contient aussi des variantes (majuscules, espace en fin de valeur). Corrigé dans STAGING ; mesuré par la règle depot_connu.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.hire_date IS
  'Date d''embauche. Une date dans le futur est une anomalie (règle dates_coherentes).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.end_date IS
  'Date de fin de contrat. Vide = chauffeur en poste. Une fin avant l''embauche est une anomalie (règle dates_coherentes). Sert à calculer l''échéance de conservation de la règle R1.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS._source_file IS
  'Colonne technique : nom du fichier d''où vient la ligne, relevé par le chargement. Ne décrit aucune personne.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS._loaded_at IS
  'Colonne technique : date et heure (sans fuseau) du chargement de la ligne dans RAW. Sert à tracer l''origine d''une ligne. Ne décrit aucune personne.';

-- 3. Les tags de la table (les colonnes en héritent)
ALTER TABLE NYC_TAXI.RAW.DRIVERS SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat';

-- 4. DONNEE_PERSONNELLE sur chaque colonne qui décrit une personne. Les deux colonnes techniques, les dates
--    d'embauche et de fin, et le dépôt n'ont pas de valeur adaptée dans la liste du contrat : sans ce tag.
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN driver_id          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN first_name         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN last_name          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN email              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'email';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN phone              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'telephone';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN birth_date         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'date_naissance';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN tlc_license_number SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_officiel';

-- 5. Vérifier : 7 colonnes portent DONNEE_PERSONNELLE
SELECT column_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVERS', 'table'))
WHERE tag_name = 'DONNEE_PERSONNELLE'
ORDER BY column_name;

-- À lancer ensuite, seule : aucune colonne sans description (0 ligne attendue)
--   SELECT column_name FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
--   WHERE table_schema = 'RAW' AND table_name = 'DRIVERS' AND comment IS NULL;
