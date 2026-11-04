-- Règle de qualité service_unique (contrat §6), mesurée sur RAW.
-- Énoncé : un identifiant de service n'apparaît qu'une fois.
-- Seuil : 0 anomalie. Gravité : avertissement (une ligne ALERTE est enregistrée, les tâches continuent).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT COUNT(*) - COUNT(DISTINCT shift_id) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
