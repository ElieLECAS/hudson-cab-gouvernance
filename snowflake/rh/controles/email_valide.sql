-- Règle de qualité email_valide (contrat §6), mesurée sur RAW.
-- Énoncé : l'adresse e-mail d'un chauffeur contient un @.
-- Seuil : 0 anomalie. Gravité : avertissement (une ligne ALERTE est enregistrée, les tâches continuent).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT COUNT_IF(email IS NULL OR email NOT LIKE '%@%') AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVERS;
