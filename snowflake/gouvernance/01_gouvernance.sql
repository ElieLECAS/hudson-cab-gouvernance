-- =====================================================================
-- 01_gouvernance.sql — ce qui porte les règles : le rôle GOUVERNANCE, son schéma, les trois tags,
-- la table des résultats de qualité, et les droits à donner dès maintenant.
-- Source : contrat §1 et §3 ; guide, jour 1, étape 10 ; modèle : exemples/00 et exemples/01.
-- Exécuter en entier (Ctrl+Maj+Entrée). Rejouable : le relancer ne casse rien.
-- Aucune politique de masquage ni d'accès par ligne ici : elles viennent au jour 2.
-- =====================================================================

-- ===================================================================== A. ACCOUNTADMIN
-- Seul ACCOUNTADMIN peut créer un rôle, et donner des droits « sur tout le compte ».
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
-- Guillemets doubles : un nom d'utilisateur comme prenom.nom en exige (sinon GRANT … TO USER échoue).
SET moi = '"' || CURRENT_USER() || '"';

-- Le rôle qui écrit les règles. Ni rattaché à SYSADMIN ni à ACCOUNTADMIN : il ne doit lire aucune donnée,
-- et un rôle parent hériterait de ses droits. On se le donne pour pouvoir l'utiliser.
CREATE ROLE IF NOT EXISTS GOUVERNANCE
  COMMENT = 'Écrit les règles : tags et politiques. Propriétaire du schéma GOUVERNANCE. Ne lit pas les données.';
GRANT ROLE GOUVERNANCE TO USER IDENTIFIER($moi);

-- Voir sans lire : entrer dans la base et dans les schémas RAW et MARTS (USAGE), jamais de SELECT.
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE GOUVERNANCE;
GRANT USAGE ON DATABASE  NYC_TAXI    TO ROLE GOUVERNANCE;
GRANT USAGE ON SCHEMA    NYC_TAXI.RAW   TO ROLE GOUVERNANCE;
GRANT USAGE ON SCHEMA    NYC_TAXI.MARTS TO ROLE GOUVERNANCE;

-- Le schéma des règles : créé par ACCOUNTADMIN, puis donné à GOUVERNANCE, qui peut alors y créer
-- tags, politiques et tables sans autre droit.
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.GOUVERNANCE
  COMMENT = 'Tags, politiques de masquage et d''accès, tables de la gouvernance';
GRANT OWNERSHIP ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE GOUVERNANCE COPY CURRENT GRANTS;

-- Attacher une politique à une table qu'on ne possède pas (jour 2) : droit « sur le compte », donné ici une fois.
GRANT APPLY MASKING POLICY    ON ACCOUNT TO ROLE GOUVERNANCE;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE GOUVERNANCE;

-- ===================================================================== B. GOUVERNANCE
-- À partir d'ici, GOUVERNANCE crée ce qu'il possède : les tags et la table des résultats.
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- Les trois tags du contrat (§3). ALLOWED_VALUES : toute autre valeur est refusée.
CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.SENSIBILITE
  ALLOWED_VALUES 'public', 'interne', 'confidentiel'
  COMMENT = 'Niveau de sensibilité d''une table. Se pose sur chaque table cataloguée.';

CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE
  ALLOWED_VALUES 'nom', 'email', 'telephone', 'date_naissance', 'identifiant_officiel', 'identifiant_interne'
  COMMENT = 'Nature de la donnée personnelle d''une colonne. Déclenchera le masquage (jour 2).';

-- Texte libre (pas de ALLOWED_VALUES) : la durée dépend de la table, par exemple « 5 ans après la fin du contrat ».
CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION
  COMMENT = 'Durée de conservation d''une table, en texte libre. Se pose sur chaque table cataloguée.';

-- La table où les tâches du jour 3 écriront le résultat de chaque règle de qualité (contrat §1 et §6).
-- Une ligne par règle et par exécution. statut vaut 'OK' ou 'ALERTE'.
CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (
    regle         VARCHAR,
    mesure_le     TIMESTAMP_NTZ,
    nb_anomalies  NUMBER,
    seuil         NUMBER(18,2),
    statut        VARCHAR
);

-- ===================================================================== C. GOUVERNANCE donne au rôle des outils
-- GOUVERNANCE possède ces objets : lui seul peut accorder ces droits à TRANSFORMER.
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE TRANSFORMER;

-- Poser un tag sur une colonne exige APPLY sur CE tag : un droit par tag, pas sur tous (étape 11, catalogue).
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.SENSIBILITE        TO ROLE TRANSFORMER;
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE TO ROLE TRANSFORMER;
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION TO ROLE TRANSFORMER;

-- Les tâches du jour 3 écrivent les résultats de qualité, puis les relisent pour décider de continuer.
GRANT INSERT, SELECT ON TABLE NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS TO ROLE TRANSFORMER;

-- La vue V_CATALOGUE (jour 3) sera créée par TRANSFORMER dans ce schéma.
GRANT CREATE VIEW ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE TRANSFORMER;

-- ===================================================================== D. Vérifier
-- Trois tags : SENSIBILITE, DONNEE_PERSONNELLE, DUREE_CONSERVATION.
SHOW TAGS IN SCHEMA NYC_TAXI.GOUVERNANCE;

-- À lancer ensuite, une requête à la fois (Ctrl+Entrée), car Snowsight n'affiche que le dernier résultat :
--   SHOW GRANTS TO ROLE TRANSFORMER;    -- USAGE schéma, 3 APPLY sur les tags, INSERT et SELECT, CREATE VIEW
--   SHOW GRANTS TO ROLE GOUVERNANCE;    -- OWNERSHIP du schéma et des tags, 2 APPLY sur le compte, aucun SELECT
-- Et la preuve que GOUVERNANCE ne lit rien (un refus est le résultat attendu) :
--   USE ROLE GOUVERNANCE;  SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS;
