-- Règle de qualité duree_plausible (contrat §6), mesurée sur RAW.
-- Énoncé : un service ne dure pas plus de 16 heures.
-- Seuil : 0 anomalie. Gravité : avertissement (une ligne ALERTE est enregistrée, les tâches continuent).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT COUNT_IF(hours_worked > 16) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
