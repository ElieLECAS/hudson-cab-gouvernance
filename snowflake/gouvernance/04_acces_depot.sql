-- =====================================================================
-- 04_acces_depot.sql — filtrer les lignes par dépôt avec une table de correspondance.
-- Source : contrat §1 (table ACCES_DEPOT) et §4 (matrice) ; guide, jour 2, étape 6 ; modèle : exemples/03.
-- À exécuter en entier avec GOUVERNANCE (Ctrl+Maj+Entrée). Rejouable.
-- Ouvrir un dépôt à un rôle = ajouter une ligne dans ACCES_DEPOT, sans toucher la politique.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. Qui voit quel dépôt : des lignes dans une table, pas des valeurs écrites dans la politique.
--    '*' veut dire « tous les dépôts ». Un rôle absent de la table ne voit aucune ligne (contrat §4).
CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.ACCES_DEPOT (
    role_name VARCHAR NOT NULL,
    depot     VARCHAR NOT NULL      -- un dépôt (Bronx, Brooklyn, Queens), ou * pour tous
);
DELETE FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT;
INSERT INTO NYC_TAXI.GOUVERNANCE.ACCES_DEPOT VALUES
    ('RH_PAIE',           '*'),
    ('ANALYSTE',          '*'),
    ('TRANSFORMER',       '*'),       -- INDISPENSABLE : sans cette ligne, le pipeline ne voit plus aucune ligne de DIM_DRIVER,
                                      -- et MART_DRIVER_MONTHLY se reconstruit avec driver_name vide partout, sans erreur
    ('RESP_DEPOT_QUEENS', 'Queens'),
    ('RESP_DEPOT_BRONX',  'Bronx');
-- Rien pour GOUVERNANCE, ACCOUNTADMIN ni SYSADMIN : ils ne voient aucune ligne des tables RH.

-- 2. La politique : appelée pour CHAQUE ligne lue, avec la valeur de la colonne depot.
--    Elle renvoie TRUE (la ligne s'affiche) ou FALSE (elle disparaît du résultat).
--    La sous-requête lit ACCES_DEPOT avec les droits du PROPRIÉTAIRE de la politique (GOUVERNANCE) :
--    les rôles métier n'ont pas besoin de lire cette table.
--    CURRENT_ROLE() : le rôle actif, pas les rôles secondaires ; la puissance du rôle n'entre pas en jeu.
CREATE ROW ACCESS POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.RAP_DEPOT
  AS (depot_ligne VARCHAR) RETURNS BOOLEAN -> FALSE;     -- corps provisoire (rejouable)

ALTER ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT SET BODY ->
  EXISTS (
    SELECT 1
    FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT a
    WHERE a.role_name = CURRENT_ROLE()
      AND a.depot IN (depot_ligne, '*')
  );

-- 3. L'attacher aux tables du domaine RH, sur la colonne depot : les deux tables de MARTS, et aussi celles de RAW
--    (le contrat §4 range RAW.DRIVERS et RAW.DRIVER_SHIFTS parmi les tables du domaine RH, et dit qu'un rôle
--    absent de la matrice, comme ACCOUNTADMIN, n'y voit aucune ligne). Les vues de STAGING lisent RAW : elles en héritent.
--    On retire d'abord ce qui est déjà attaché : DROP ALL ne fait rien s'il n'y a rien, ADD échouerait s'il y avait
--    déjà une politique. Entre les deux commandes, la table est brièvement non filtrée : à lancer hors usage.
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER          DROP ALL ROW ACCESS POLICIES;
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER          ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY DROP ALL ROW ACCESS POLICIES;
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);
ALTER TABLE NYC_TAXI.RAW.DRIVERS               DROP ALL ROW ACCESS POLICIES;
ALTER TABLE NYC_TAXI.RAW.DRIVERS               ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS         DROP ALL ROW ACCESS POLICIES;
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS         ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);

-- 4. Vérifier. Attendu sur DIM_DRIVER : 8 lignes = les 7 politiques de masquage du fichier 03
--    (6 MASK_TEXTE, 1 MASK_DATE) et la politique d'accès par ligne RAP_DEPOT sur la colonne depot.
SELECT policy_name, policy_kind, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.DIM_DRIVER', REF_ENTITY_DOMAIN => 'TABLE'))
ORDER BY policy_kind, ref_column_name;

-- À lancer ensuite, une requête à la fois (Ctrl+Entrée), car Snowsight n'affiche que le dernier résultat :
--   SELECT * FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT;      -- 5 lignes : RH_PAIE, ANALYSTE, TRANSFORMER, RESP_DEPOT_QUEENS, RESP_DEPOT_BRONX
--   SHOW ROW ACCESS POLICIES IN SCHEMA NYC_TAXI.GOUVERNANCE;   -- 1 ligne : RAP_DEPOT
-- Pour ouvrir un dépôt, sans toucher la politique (à faire avec un rôle qui existe) :
--   INSERT INTO NYC_TAXI.GOUVERNANCE.ACCES_DEPOT VALUES ('<ROLE>', 'Brooklyn');
