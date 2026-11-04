-- =====================================================================
-- 02_roles_metier.sql — les quatre rôles métier et leurs droits de lecture.
-- Source : contrat §4 (matrice des accès) ; guide, jour 2, étape 2.
-- À exécuter en entier avec ACCOUNTADMIN (Ctrl+Maj+Entrée). Rejouable : le relancer ne casse rien.
-- Ce script donne le droit de LIRE les tables. Ce que chaque rôle voit en clair (masquage) et quelles lignes
-- il voit (dépôt) viendront des politiques, écrites ensuite par GOUVERNANCE (03 et 04).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
-- Guillemets doubles : un nom d'utilisateur comme prenom.nom en exige (sinon GRANT … TO USER échoue).
SET moi = '"' || CURRENT_USER() || '"';

-- 1. Les rôles. Ni rattachés à SYSADMIN, ni entre eux : chacun ne fait que son métier, et un rôle parent
--    hériterait de ses droits. On se les donne pour pouvoir les tester (un rôle à la fois).
CREATE ROLE IF NOT EXISTS RH_PAIE           COMMENT = 'Service paie : lit tout, tous les dépôts';
CREATE ROLE IF NOT EXISTS RESP_DEPOT_QUEENS COMMENT = 'Responsable du dépôt de Queens : voit son dépôt, nom, prénom, téléphone';
CREATE ROLE IF NOT EXISTS RESP_DEPOT_BRONX  COMMENT = 'Responsable du dépôt du Bronx : voit son dépôt, nom, prénom, téléphone';
CREATE ROLE IF NOT EXISTS ANALYSTE          COMMENT = 'Priya, analyste : tous les dépôts, aucune donnée qui identifie un chauffeur directement';
GRANT ROLE RH_PAIE           TO USER IDENTIFIER($moi);
GRANT ROLE RESP_DEPOT_QUEENS TO USER IDENTIFIER($moi);
GRANT ROLE RESP_DEPOT_BRONX  TO USER IDENTIFIER($moi);
GRANT ROLE ANALYSTE          TO USER IDENTIFIER($moi);

-- 2. Entrer dans la base et dans MARTS, et exécuter des requêtes : pour les quatre rôles.
--    Aucun droit sur RAW ni sur STAGING : le contrat (§4) les réserve au rôle des outils.
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE RH_PAIE;
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE RESP_DEPOT_QUEENS;
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE RESP_DEPOT_BRONX;
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE ANALYSTE;
GRANT USAGE ON DATABASE  NYC_TAXI    TO ROLE RH_PAIE;
GRANT USAGE ON DATABASE  NYC_TAXI    TO ROLE RESP_DEPOT_QUEENS;
GRANT USAGE ON DATABASE  NYC_TAXI    TO ROLE RESP_DEPOT_BRONX;
GRANT USAGE ON DATABASE  NYC_TAXI    TO ROLE ANALYSTE;
GRANT USAGE ON SCHEMA    NYC_TAXI.MARTS TO ROLE RH_PAIE;
GRANT USAGE ON SCHEMA    NYC_TAXI.MARTS TO ROLE RESP_DEPOT_QUEENS;
GRANT USAGE ON SCHEMA    NYC_TAXI.MARTS TO ROLE RESP_DEPOT_BRONX;
GRANT USAGE ON SCHEMA    NYC_TAXI.MARTS TO ROLE ANALYSTE;

-- 3. Lire les tables : la paie et les deux responsables de dépôt lisent les deux tables du domaine RH
--    de MARTS et le référentiel des dépôts. Seul ce qui est nommé : aucune table future.
GRANT SELECT ON TABLE NYC_TAXI.MARTS.DIM_DRIVER          TO ROLE RH_PAIE;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY TO ROLE RH_PAIE;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.DIM_DEPOT           TO ROLE RH_PAIE;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.DIM_DRIVER          TO ROLE RESP_DEPOT_QUEENS;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY TO ROLE RESP_DEPOT_QUEENS;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.DIM_DEPOT           TO ROLE RESP_DEPOT_QUEENS;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.DIM_DRIVER          TO ROLE RESP_DEPOT_BRONX;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY TO ROLE RESP_DEPOT_BRONX;
GRANT SELECT ON TABLE NYC_TAXI.MARTS.DIM_DEPOT           TO ROLE RESP_DEPOT_BRONX;

-- L'analyste lit toutes les tables de MARTS, y compris celles qui seront créées plus tard : sans le droit
-- sur les tables futures, il perdrait une table chaque fois que le pipeline en crée une nouvelle.
-- Ce droit « futur » ne se donne qu'avec ACCOUNTADMIN (il demande le privilège de gérer les droits).
GRANT SELECT ON ALL TABLES    IN SCHEMA NYC_TAXI.MARTS TO ROLE ANALYSTE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA NYC_TAXI.MARTS TO ROLE ANALYSTE;

-- 4. Lire le catalogue : la vue GOUVERNANCE.V_CATALOGUE sera créée au jour 3 par TRANSFORMER. Les quatre rôles
--    peuvent entrer dans le schéma GOUVERNANCE, mais ne lisent que les vues (jamais ACCES_DEPOT ni QUALITE_RESULTATS).
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE RH_PAIE;
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE RESP_DEPOT_QUEENS;
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE RESP_DEPOT_BRONX;
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE ANALYSTE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE RH_PAIE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE RESP_DEPOT_QUEENS;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE RESP_DEPOT_BRONX;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE ANALYSTE;

-- 5. Vérifier : la carte des droits de l'analyste (le rôle le plus large).
--    Attendu : USAGE sur le warehouse, la base, MARTS et GOUVERNANCE, et SELECT sur DIM_DEPOT, DIM_DRIVER
--    et MART_DRIVER_MONTHLY (7 lignes). Aucune ligne sur RAW ni STAGING.
SHOW GRANTS TO ROLE ANALYSTE;

-- À lancer ensuite, une requête à la fois (Ctrl+Entrée), car Snowsight n'affiche que le dernier résultat :
--   SHOW GRANTS TO ROLE RH_PAIE;               -- 7 lignes : USAGE ×4 (warehouse, base, MARTS, GOUVERNANCE) et SELECT ×3
--   SHOW GRANTS TO ROLE RESP_DEPOT_QUEENS;     -- idem : 7 lignes
--   SHOW GRANTS TO ROLE RESP_DEPOT_BRONX;      -- idem : 7 lignes
--   SHOW FUTURE GRANTS TO ROLE ANALYSTE;       -- 2 lignes : SELECT sur les tables futures de MARTS, sur les vues futures de GOUVERNANCE
--   SHOW FUTURE GRANTS TO ROLE RH_PAIE;        -- 1 ligne : SELECT sur les vues futures de GOUVERNANCE
-- (SHOW GRANTS ne liste pas les droits « futurs » : ils ont leur propre commande.)
