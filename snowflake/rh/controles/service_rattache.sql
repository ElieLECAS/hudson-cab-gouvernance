-- Règle de qualité service_rattache (contrat §6), mesurée sur RAW.
-- Énoncé : chaque service appartient à un chauffeur connu.
-- Seuil : 50 services. Gravité : bloquant (résultat enregistré, puis la tâche T_QUALITE s'arrête : T_TABLES ne part pas).
-- Une requête, une ligne, une colonne : le nombre de lignes en anomalie. Zéro = règle respectée.
SELECT COUNT(*) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id);
