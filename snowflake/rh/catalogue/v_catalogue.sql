-- =====================================================================
-- v_catalogue.sql — la vue du catalogue : une ligne par colonne des trois tables de MARTS.
-- Source : contrat §1 (GOUVERNANCE.V_CATALOGUE) ; guide, jour 3 ; modèle : exemples/04.
-- À exécuter avec TRANSFORMER (propriétaire de la vue : il a reçu CREATE VIEW sur le schéma GOUVERNANCE dans
-- 01_gouvernance.sql ; le rôle GOUVERNANCE, lui, ne voit pas les tables). Rejouable.
--
-- Chaque ligne donne : la table et sa description, la colonne, son type, sa description, et la valeur des trois
-- tags. SENSIBILITE et DUREE_CONSERVATION sont posés sur la table et hérités par ses colonnes ; DONNEE_PERSONNELLE
-- est posé colonne par colonne. Les descriptions viennent d'INFORMATION_SCHEMA.COLUMNS, les tags de la fonction
-- TAG_REFERENCES_ALL_COLUMNS, qu'on appelle pour UNE table à la fois : un bloc par table, réunis par UNION ALL.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

CREATE OR REPLACE VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE AS
WITH tags AS (
    SELECT 'DIM_DRIVER' AS table_name, column_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
    UNION ALL
    SELECT 'MART_DRIVER_MONTHLY', column_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
    UNION ALL
    SELECT 'DIM_DEPOT', column_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DEPOT', 'table'))
)
SELECT
    c.table_name,
    t.comment                                                         AS description_table,
    c.ordinal_position                                                AS position,
    c.column_name,
    c.data_type,
    c.comment                                                         AS description,
    MAX(IFF(g.tag_name = 'DONNEE_PERSONNELLE', g.tag_value, NULL))    AS donnee_personnelle,
    MAX(IFF(g.tag_name = 'SENSIBILITE',        g.tag_value, NULL))    AS sensibilite,
    MAX(IFF(g.tag_name = 'DUREE_CONSERVATION', g.tag_value, NULL))    AS duree_conservation
FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS c
JOIN NYC_TAXI.INFORMATION_SCHEMA.TABLES t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
LEFT JOIN tags g
  ON g.table_name = c.table_name AND g.column_name = c.column_name
WHERE c.table_schema = 'MARTS'
  AND c.table_name IN ('DIM_DRIVER', 'MART_DRIVER_MONTHLY', 'DIM_DEPOT')
GROUP BY c.table_name, t.comment, c.ordinal_position, c.column_name, c.data_type, c.comment;

-- Les quatre rôles métier lisent la vue (ils avaient déjà un droit sur les vues futures du schéma ;
-- on le redonne explicitement, ce qui ne coûte rien et rend le script autonome).
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE RH_PAIE;
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE RESP_DEPOT_QUEENS;
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE RESP_DEPOT_BRONX;
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE ANALYSTE;

-- Vérifier, avec le propriétaire : 24 lignes (12 + 8 + 4), 9 colonnes personnelles (7 de DIM_DRIVER, 2 du mart).
SELECT COUNT(*) AS nb_colonnes, COUNT(donnee_personnelle) AS nb_colonnes_personnelles,
       COUNT(DISTINCT table_name) AS nb_tables, COUNT(description) AS nb_avec_description
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE;
