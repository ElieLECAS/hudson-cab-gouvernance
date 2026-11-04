-- =====================================================================
-- test_v_catalogue.sql — un rôle métier (ANALYSTE) lit-il V_CATALOGUE ? C'est un moment de la démonstration.
-- À exécuter en entier (Ctrl+Maj+Entrée). Lecture seule. Il renvoie UNE ligne de comptes.
-- Attendu (24 colonnes, 9 personnelles, 3 tables, 24 avec description) : les mêmes comptes que le propriétaire.
-- Si les comptes sont plus petits ou nuls, c'est INFORMATION_SCHEMA qui ne montre que ce que le rôle actif voit :
-- il faudra alors passer par une table de catalogue rafraîchie par TRANSFORMER (voir le README).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;

SELECT CURRENT_ROLE() AS role_actif,
       COUNT(*) AS nb_colonnes, COUNT(donnee_personnelle) AS nb_colonnes_personnelles,
       COUNT(DISTINCT table_name) AS nb_tables, COUNT(description) AS nb_avec_description,
       COUNT_IF(column_name = 'EMAIL' AND donnee_personnelle = 'email' AND description IS NOT NULL) AS email_decrite_et_taguee
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE;
