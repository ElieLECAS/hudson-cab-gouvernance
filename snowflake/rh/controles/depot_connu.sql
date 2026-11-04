-- Règle de qualité depot_connu (contrat §6), mesurée sur RAW.
-- Énoncé : le dépôt est écrit exactement Bronx, Brooklyn ou Queens (chauffeurs et services).
-- Seuil : 0 anomalie. Gravité : avertissement (une ligne ALERTE est enregistrée, les tâches continuent).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVERS)
     + (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVER_SHIFTS) AS nb_anomalies;
