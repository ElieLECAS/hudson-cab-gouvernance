-- =====================================================================
-- catalogue_mart_driver_monthly.sql — fiche de catalogue COURTE de NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.
-- À exécuter avec TRANSFORMER, propriétaire de la table. Rejouable : COMMENT et SET TAG remplacent la valeur.
-- Point d'attention : driver_name est une colonne CALCULÉE (prénom, espace, nom). Elle contient le nom en clair
-- dans une table d'activité : elle doit porter le tag DONNEE_PERSONNELLE, comme first_name et last_name.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY IS
  'Activité mensuelle des chauffeurs : 1 ligne = 1 chauffeur, 1 dépôt de service et 1 mois (services, heures, courses, recette). Source : la vue STAGING.STG_RH__DRIVER_SHIFTS (services dédoublonnés), jointe à DIM_DRIVER pour le nom. Reconstruite par INSERT OVERWRITE à chaque exécution des tâches (T_TABLES). Responsable du traitement : Hudson Cab Europe (Paris) ; propriétaire technique : équipe data.';

-- 2. Les colonnes (descriptions brèves)
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.activity_month IS
  'Mois de l''activité, représenté par son premier jour (par exemple 2025-01-01).';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.driver_id IS
  'Identifiant interne du chauffeur (pseudonyme), pour compter et joindre sans nommer.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.driver_name IS
  'Colonne calculée : prénom et nom du chauffeur, séparés par un espace, repris de DIM_DRIVER. Vide si le service n''est rattaché à aucun chauffeur connu (règle de qualité service_rattache).';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.depot IS
  'Dépôt où les services ont été faits (celui du service, pas forcément le dépôt de rattachement du chauffeur). Filtre les lignes visibles par les responsables de dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.nb_shifts IS
  'Nombre de services du chauffeur ce mois-là, dans ce dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.hours_worked IS
  'Total des heures travaillées dans le mois, arrondi à une décimale.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.trips_count IS
  'Nombre total de courses effectuées dans le mois.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.revenue_usd IS
  'Recette totale du mois, en dollars américains, arrondie au centime.';

-- 3. Les deux tags de table
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur';

-- 4. DONNEE_PERSONNELLE : le pseudonyme, et le nom calculé
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_id   SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_name SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';

-- 5. Vérifier : 2 colonnes (driver_id et driver_name)
SELECT column_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
WHERE tag_name = 'DONNEE_PERSONNELLE'
ORDER BY column_name;
