-- Règle de qualité dates_coherentes (contrat §6), mesurée sur RAW.
-- Énoncé : pas d'embauche dans le futur, pas de fin de contrat avant l'embauche.
-- Seuil : 0 anomalie. Gravité : avertissement (une ligne ALERTE est enregistrée, les tâches continuent).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT COUNT_IF(hire_date > CURRENT_DATE() OR end_date < hire_date) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVERS;
