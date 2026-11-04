-- =====================================================================
-- 03_masquage.sql — les politiques de masquage, attachées au TAG DONNEE_PERSONNELLE.
-- Source : contrat §4 (matrice des accès) ; guide, jour 2, étape 5 ; modèle : exemples/02.
-- À exécuter en entier avec GOUVERNANCE (Ctrl+Maj+Entrée). Rejouable : on peut le relancer après avoir
-- modifié une règle. GOUVERNANCE a reçu le droit d'attacher des politiques au jour 1 (01_gouvernance.sql, bloc A).
-- Valeurs masquées (voir docs/ACCES.md, partie 2) : '*****' pour un texte ; NULL pour une date, sauf
-- l'ANALYSTE qui lit le 1er janvier de l'année de naissance. Une politique renvoie le type qu'elle reçoit :
-- il en faut une par type de colonne taguée (texte, date).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- ===================================================================== A. Le texte
-- Rejouable, étape 1 : créer la politique si elle n'existe pas, avec un corps provisoire.
-- (CREATE OR REPLACE échouerait au second passage : on ne remplace pas une politique attachée.)
CREATE MASKING POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.MASK_TEXTE
  AS (val STRING) RETURNS STRING -> val;

-- Rejouable, étape 2 : écrire le vrai corps. ALTER … SET BODY fonctionne même si la politique est attachée.
-- L'ordre des WHEN compte : le premier qui s'applique gagne.
ALTER MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_TEXTE SET BODY ->
  CASE
    -- 1. L'exception : une colonne taguée 'identifiant_interne' (driver_id) reste visible de tous les rôles
    --    métier, pour compter et joindre sans nommer (contrat §4). La politique lit la valeur du tag de la
    --    colonne en cours de lecture.
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') = 'identifiant_interne'
      THEN val
    -- 2. Le rôle des outils lit tout en clair : s'il lisait un masque, le pipeline l'écrirait dans les tables
    --    (driver_name vide ou '*****' dans MART_DRIVER_MONTHLY, sans aucune erreur).
    WHEN CURRENT_ROLE() = 'TRANSFORMER'
      THEN val
    -- 3. La paie voit tout.
    WHEN CURRENT_ROLE() = 'RH_PAIE'
      THEN val
    -- 4. Les responsables de dépôt : nom, prénom et téléphone seulement (pas l'e-mail ni la licence).
    WHEN CURRENT_ROLE() IN ('RESP_DEPOT_QUEENS', 'RESP_DEPOT_BRONX')
         AND SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') IN ('nom', 'telephone')
      THEN val
    -- 5. Tous les autres, dont ANALYSTE, ACCOUNTADMIN, SYSADMIN et GOUVERNANCE : masqué (refus par défaut).
    --    Un rôle absent de cette liste ne voit jamais une valeur par oubli.
    ELSE '*****'
  END;

-- ===================================================================== B. Les dates
CREATE MASKING POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.MASK_DATE
  AS (val DATE) RETURNS DATE -> val;

ALTER MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_DATE SET BODY ->
  CASE
    WHEN CURRENT_ROLE() = 'TRANSFORMER' THEN val
    WHEN CURRENT_ROLE() = 'RH_PAIE'     THEN val
    -- L'analyste lit l'année de naissance seulement : le 1er janvier de cette année. C'est encore une date,
    -- donc YEAR(birth_date) fonctionne.
    WHEN CURRENT_ROLE() = 'ANALYSTE'    THEN DATE_TRUNC('year', val)::DATE
    ELSE NULL
  END;

-- ===================================================================== C. Attacher au tag
-- On attache les deux politiques AU TAG (et non aux colonnes) : toute colonne qui porte DONNEE_PERSONNELLE,
-- aujourd'hui (RAW, MARTS) ou demain, est protégée. Cette commande échoue si c'est déjà fait : le bloc
-- ci-dessous attrape l'erreur et affiche son message, pour que le script reste rejouable.
EXECUTE IMMEDIATE $$
BEGIN
  ALTER TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE SET
    MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_TEXTE,
    MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_DATE;
  RETURN 'Politiques attachées au tag.';
EXCEPTION
  WHEN STATEMENT_ERROR THEN
    RETURN 'Non attachées, lire le message (déjà attachées ?) : ' || SQLERRM;
END;
$$;

-- ===================================================================== D. Vérifier
-- Attendu sur DIM_DRIVER : 7 lignes, 6 colonnes en MASK_TEXTE (driver_id, first_name, last_name, email, phone,
-- tlc_license_number) et 1 en MASK_DATE (birth_date), toutes par le tag DONNEE_PERSONNELLE.
SELECT policy_name, policy_kind, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.DIM_DRIVER', REF_ENTITY_DOMAIN => 'TABLE'))
ORDER BY ref_column_name;

-- À lancer ensuite, une requête à la fois (Ctrl+Entrée), car Snowsight n'affiche que le dernier résultat :
--   SHOW MASKING POLICIES IN SCHEMA NYC_TAXI.GOUVERNANCE;     -- 2 lignes : MASK_DATE, MASK_TEXTE
-- Et sur MART_DRIVER_MONTHLY : 2 lignes (driver_id, driver_name), en changeant le nom de la table ci-dessus.
