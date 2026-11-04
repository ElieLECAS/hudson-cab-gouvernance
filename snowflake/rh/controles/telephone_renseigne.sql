-- Règle de qualité telephone_renseigne (contrat §6), mesurée sur RAW.
-- Énoncé : chaque chauffeur en poste a un numéro de téléphone.
-- Seuil : 5 % des chauffeurs en poste, converti en nombre au moment de la mesure. Gravité : avertissement (une ligne ALERTE est enregistrée, les tâches continuent).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT COUNT_IF(phone IS NULL OR TRIM(phone) = '') AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVERS
WHERE end_date IS NULL;
