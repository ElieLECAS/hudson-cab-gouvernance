# Registre du traitement — données du personnel

Ce fichier se remplit en deux temps :

- **Partie 1, jour 1** : l'inventaire des données personnelles des deux fichiers, avant tout chargement ;
- **Partie 2, jour 3** : la fiche de registre, qui s'appuie sur l'inventaire et sur ce que vous avez construit.

---

## Partie 1 — Inventaire des données personnelles (jour 1)

Une donnée personnelle est une information qui se rapporte à une personne identifiée ou identifiable (RGPD, art. 4 point 1). Trois cas à distinguer :

- **identifiant direct** : la colonne suffit à désigner la personne (un nom, un e-mail) ;
- **identifiant indirect** : la colonne ne suffit pas seule, mais permet d'identifier quelqu'un une fois combinée à d'autres (une date de naissance et un dépôt) ;
- **pas une donnée personnelle** : la colonne ne dit rien d'une personne.

Les exemples de valeur sont **inventés** : ce fichier est public, aucune ligne du fichier RH n'y figure. Les valeurs du tag `DONNEE_PERSONNELLE` sont celles de la liste fermée du contrat. Quand aucune valeur ne convient, la case dit « aucune » : on n'invente pas de valeur.

### `drivers.csv` : les colonnes

| Colonne | Exemple de valeur | Donnée personnelle ? (direct, indirect, non) | Valeur du tag `DONNEE_PERSONNELLE` | Qui en a besoin, et pour quoi faire |
|---|---|---|---|---|
| `driver_id` | `D0001` | **Indirect (pseudonyme)** : il ne nomme personne seul, mais il relie toutes les lignes d'une même personne, et la table `DRIVERS` le relie à son nom. Une donnée pseudonymisée reste une donnée personnelle (art. 4 point 5). | `identifiant_interne` | Tous les rôles métier : compter et joindre les tables sans nommer. |
| `first_name` | `Prénom` | **Direct** | `nom` | `RH_PAIE` : établir la paie. Les responsables de dépôt : encadrer leur équipe. Pas `ANALYSTE`. |
| `last_name` | `Nom` | **Direct** | `nom` | Idem `first_name`. |
| `email` | `prenom.nom@exemple.test` | **Direct** : il désigne une personne et permet de la joindre. | `email` | `RH_PAIE` : joindre le salarié pour la paie. Pas les responsables de dépôt (ils ne l'ont pas dans la matrice), pas `ANALYSTE`. |
| `phone` | `+1 (000) 000-0000` | **Direct** | `telephone` | `RH_PAIE` et les responsables de dépôt : joindre les chauffeurs de leur dépôt. |
| `birth_date` | `1980-01-01` | **Indirect** : seule, elle ne désigne personne, mais avec le dépôt et les dates d'embauche elle réduit fortement le nombre de candidats. Elle est aussi associée au nom dans la même table. | `date_naissance` | `RH_PAIE` : date complète à justifier. `ANALYSTE` : l'année seulement (analyse par tranche d'âge). |
| `tlc_license_number` | `1234567` | **Direct** : numéro officiel délivré à une personne par la TLC, unique. | `identifiant_officiel` | `RH_PAIE` : vérifier que le chauffeur est autorisé à conduire (à confirmer). Personne d'autre dans la matrice. La règle de qualité `licence_unique` s'exécute avec `TRANSFORMER`. |
| `depot` | `Bronx` | **Non en soi** (3 valeurs seulement), mais **quasi-identifiant** quand on la combine à d'autres colonnes. | aucune (pas de valeur adaptée dans la liste) | Tous les rôles métier : c'est elle qui filtre les lignes visibles par dépôt. |
| `hire_date` | `2015-06-01` | **Indirect** : décrit la vie professionnelle d'une personne ; permet de réduire le nombre de candidats avec le dépôt. | aucune | `RH_PAIE` : ancienneté. `ANALYSTE` : ancienneté moyenne (`tenure_years`). |
| `end_date` | `2024-03-31` | **Indirect** : même raison. Elle **déclenche la règle R1** (suppression 5 ans après la fin du contrat). | aucune | `RH_PAIE` : solde de tout compte. La purge R1 (`TRANSFORMER`) : calculer l'échéance. `ANALYSTE` : savoir si le chauffeur est en poste (`is_active`). |

### `driver_shifts.csv` : les colonnes

| Colonne | Exemple de valeur | Donnée personnelle ? (direct, indirect, non) | Valeur du tag `DONNEE_PERSONNELLE` | Qui en a besoin, et pour quoi faire |
|---|---|---|---|---|
| `shift_id` | `S000001` | **Non** : identifie un service, pas une personne. | aucune | La règle de qualité `service_unique` (`TRANSFORMER`). |
| `driver_id` | `D0001` | **Indirect (pseudonyme)** : c'est elle qui rattache chaque service à une personne. | `identifiant_interne` | Tous les rôles métier : agréger l'activité par chauffeur sans le nommer. |
| `shift_date` | `2025-01-15` | **Non en soi**, personnelle dès qu'elle est rattachée à `driver_id` (elle dit quand une personne a travaillé). | aucune | `RH_PAIE` : paie. `ANALYSTE` : activité par mois. |
| `depot` | `Queens` | **Non en soi**, comme dans `drivers.csv`. | aucune | Tous les rôles métier : filtre des lignes par dépôt. |
| `start_hour` | `6` | **Non en soi**, personnelle par `driver_id` (horaires de travail). | aucune | `RH_PAIE` : paie. Responsables de dépôt : planning de leur dépôt. |
| `hours_worked` | `7.5` | **Non en soi**, personnelle par `driver_id` (mesure du temps de travail d'une personne). | aucune | `RH_PAIE` : paie. `ANALYSTE` : total mensuel. |
| `trips_count` | `20` | **Non en soi**, personnelle par `driver_id` (mesure de l'activité d'une personne). | aucune | `ANALYSTE` : volume d'activité. |
| `revenue_usd` | `525.58` | **Non en soi**, personnelle par `driver_id` (recette générée par une personne). | aucune | `ANALYSTE` : chiffre d'affaires par mois. |

Les colonnes techniques `_source_file` et `_loaded_at`, ajoutées au chargement dans `RAW`, ne décrivent aucune personne : elles ne sont pas personnelles.

### Où cette donnée est-elle copiée ?

Pour chaque colonne personnelle : la liste des tables et des vues de l'entrepôt où elle se retrouve, y compris sous une autre forme (colonne renommée, colonne calculée). Relevé dans les SQL de `snowflake/rh/`, vérifié à la fin du jour 3 : aucune copie n'a été ajoutée depuis le jour 1 (le catalogue, les règles de qualité, les tâches et l'audit ne recopient aucune donnée de personne : `V_CATALOGUE` contient des noms de colonnes, des descriptions et des tags ; `QUALITE_RESULTATS` des comptes). Les tables de rapport créées pendant la purge sont temporaires et ne contiennent que des nombres.

| Colonne d'origine | Table ou vue | Colonne | Sous quelle forme |
|---|---|---|---|
| tout le fichier `drivers.csv` et `driver_shifts.csv` | `@NYC_TAXI.RAW.RH_STAGE` (stage) | fichiers CSV complets | copie brute, jusqu'au chargement (règle R3) |
| `driver_id` | `RAW.DRIVERS`, `RAW.DRIVER_SHIFTS` | `driver_id` | copie fidèle |
| `driver_id` | `STAGING.STG_RH__DRIVERS`, `STG_RH__DRIVER_SHIFTS` (vues) | `driver_id` | identique |
| `driver_id` | `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY` | `driver_id` | identique |
| `first_name`, `last_name` | `RAW.DRIVERS` | `first_name`, `last_name` | copie fidèle |
| `first_name`, `last_name` | `STAGING.STG_RH__DRIVERS` (vue) | `first_name`, `last_name` | identique |
| `first_name`, `last_name` | `MARTS.DIM_DRIVER` | `first_name`, `last_name` | identique |
| `first_name`, `last_name` | `MARTS.MART_DRIVER_MONTHLY` | `driver_name` | **colonne calculée** : prénom, espace, nom. Le nom en clair se retrouve dans une table d'activité |
| `email` | `RAW.DRIVERS` | `email` | copie fidèle |
| `email` | `STAGING.STG_RH__DRIVERS` (vue) | `email` | passé en minuscules, espaces retirés |
| `email` | `MARTS.DIM_DRIVER` | `email` | identique à `STAGING` |
| `phone` | `RAW.DRIVERS` | `phone` | copie fidèle |
| `phone` | `STAGING.STG_RH__DRIVERS` (vue) | `phone` | espaces retirés, chaîne vide devenue `NULL` |
| `phone` | `MARTS.DIM_DRIVER` | `phone` | identique à `STAGING` |
| `birth_date` | `RAW.DRIVERS` | `birth_date` | copie fidèle |
| `birth_date` | `STAGING.STG_RH__DRIVERS` (vue) | `birth_date` | converti en date |
| `birth_date` | `MARTS.DIM_DRIVER` | `birth_date` | identique à `STAGING` |
| `tlc_license_number` | `RAW.DRIVERS` | `tlc_license_number` | copie fidèle |
| `tlc_license_number` | `STAGING.STG_RH__DRIVERS` (vue) | `tlc_license_number` | identique |
| `tlc_license_number` | `MARTS.DIM_DRIVER` | `tlc_license_number` | identique |
| `hire_date`, `end_date` | `RAW.DRIVERS`, `STG_RH__DRIVERS`, `MARTS.DIM_DRIVER` | `hire_date`, `end_date` | copie, puis converties en date, puis identiques |
| `hire_date`, `end_date` | `MARTS.DIM_DRIVER` | `is_active`, `tenure_years` | **colonnes calculées** : `is_active` dérive de `end_date`, `tenure_years` de `hire_date` et `end_date` |
| `depot` | `RAW.DRIVERS`, `RAW.DRIVER_SHIFTS` | `depot` | copie fidèle (avec les erreurs d'écriture) |
| `depot` | `STAGING.STG_RH__DRIVERS`, `STG_RH__DRIVER_SHIFTS` (vues) | `depot` | espaces retirés, majuscule initiale : les écarts du fichier sont corrigés ici |
| `depot` | `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY` | `depot` | identique à `STAGING` ; dans `MART_DRIVER_MONTHLY`, c'est le dépôt du service |
| `shift_date`, `hours_worked`, `trips_count`, `revenue_usd` | `RAW.DRIVER_SHIFTS`, `STG_RH__DRIVER_SHIFTS` | mêmes noms | copie, puis converties en types |
| `shift_date`, `hours_worked`, `trips_count`, `revenue_usd` | `MARTS.MART_DRIVER_MONTHLY` | `activity_month`, `hours_worked`, `trips_count`, `revenue_usd`, `nb_shifts` | **agrégées par chauffeur et par mois** : le détail du service disparaît, le lien avec la personne reste |
| toutes les colonnes de `RAW` | historique Time Travel (1 jour) puis Fail-safe (7 jours) des tables ci-dessus | toutes | copies conservées par Snowflake après suppression ou modification (voir `VEILLE.md`, fiche 6). Les 46 chauffeurs purgés le 4 novembre 2026 y restent donc jusqu'à 8 jours. |

Hors de l'entrepôt : les copies locales des CSV (poste de travail, téléchargements) sont des copies supplémentaires, à supprimer à la fin du brief.

### Ce qui a surpris

- **Le nom du chauffeur s'est glissé dans une table d'activité.** `MART_DRIVER_MONTHLY` est une table de chiffres (services, heures, recette), lue par `ANALYSTE`, et elle contient pourtant `driver_name`, calculée à partir du prénom et du nom. Cette colonne n'est pas dans le fichier d'origine : elle doit être cataloguée et protégée comme les autres.
- **Des colonnes d'apparence neutre deviennent personnelles.** Heures, courses et recette ne disent rien d'une personne seules ; avec `driver_id`, elles mesurent le travail de quelqu'un. Il en va de même pour `is_active` et `tenure_years`, qui cachent `end_date` et `hire_date`.
- **Des données qui n'auraient pas dû rester dans le fichier.** À la date du 3 novembre 2026, 46 chauffeurs sont partis depuis plus de 5 ans : leurs données auraient dû être supprimées (règle R1). Par ailleurs, la date de naissance complète et le numéro de licence ne sont attendus que par `RH_PAIE` dans la matrice : tous les autres rôles n'en ont pas besoin.

---

## Partie 2 — Fiche de registre (jour 3)

Le registre des activités de traitement décrit ce qu'une organisation fait des données personnelles qu'elle détient. Cette fiche en est une version réduite, limitée à ce qu'un Data Engineer peut renseigner et prouver. La trame complète est celle de la CNIL (lien dans les ressources).

Chaque réponse de la colonne de droite peut être vérifiée dans l'entrepôt : la requête ou le fichier qui le prouve est indiqué. Relevés du 4 novembre 2026. Les captures sont dans `docs/`, sans valeur de personne.

### Le traitement

| Rubrique | Réponse |
|---|---|
| Nom du traitement | Gestion du personnel chauffeur : fichier RH et relevé des services de Hudson Cab Partners |
| Finalité : à quoi servent ces données | Établir la paie (`RH_PAIE`), encadrer les équipes de chaque dépôt (responsables de dépôt), analyser l'activité sans identifier de chauffeur (`ANALYSTE`), vérifier l'autorisation de conduire (numéro de licence TLC, à confirmer avec la direction RH). |
| Personnes concernées | Les chauffeurs de Hudson Cab Partners, en poste ou partis depuis moins de 5 ans : 354 dans l'entrepôt après la purge du 4 novembre 2026 (400 dans le fichier reçu). Le fichier est fictif, mais traité comme un vrai fichier du personnel. |
| Service responsable des données | Hudson Cab Europe (Paris), responsable du traitement depuis le transfert de la gestion (`docs/VEILLE.md`, section 1). Le DPO n'est pas désigné dans les documents reçus : question ouverte (`docs/VEILLE.md`, section 5). Snowflake est sous-traitant ; le compte est hébergé à Londres (`AWS_EU_WEST_2`). |

### Les données

| Catégorie de données | Colonnes concernées | Tables où elles se trouvent |
|---|---|---|
| Identité | `driver_id` (pseudonyme), `first_name`, `last_name` (et `driver_name`, colonne calculée), `birth_date`, `tlc_license_number` (identifiant officiel) | `RAW.DRIVERS`, vue `STAGING.STG_RH__DRIVERS`, `MARTS.DIM_DRIVER` ; `driver_id` et `driver_name` aussi dans `MARTS.MART_DRIVER_MONTHLY` ; `driver_id` aussi dans `RAW.DRIVER_SHIFTS` |
| Coordonnées | `email`, `phone` | `RAW.DRIVERS`, vue `STAGING.STG_RH__DRIVERS`, `MARTS.DIM_DRIVER` |
| Vie professionnelle | `depot`, `hire_date`, `end_date`, `is_active`, `tenure_years` ; services : `shift_date`, `start_hour`, `hours_worked`, `trips_count`, `revenue_usd` (personnels par `driver_id`) | `RAW.DRIVERS`, `RAW.DRIVER_SHIFTS`, vues de `STAGING`, `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY` |

Preuve : `docs/REGISTRE.md` partie 1 (inventaire colonne par colonne) ; `GOUVERNANCE.V_CATALOGUE` (une ligne par colonne des trois tables de `MARTS`, avec description et tags : 24 colonnes, 9 personnelles, lue à l'identique par `ANALYSTE`).

### Qui y accède

| Rôle | Ce qu'il voit | Pourquoi il en a besoin | Preuve (requête ou test) |
|---|---|---|---|
| `RH_PAIE` | tous les dépôts, tout en clair, date de naissance complète | établir la paie | cahier de tests : tests 1, 8, 11 et valeurs de `D0003` ; `snowflake/gouvernance/tests/test_acces_rh_paie.sql` |
| `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX` | leur dépôt seulement (161 et 122 chauffeurs) ; nom, prénom, téléphone en clair ; e-mail, licence et naissance masqués | encadrer l'équipe et joindre les chauffeurs de leur dépôt | tests 2, 3, 4, 17, 18, 24 ; `test_acces_resp_depot_queens.sql`, `test_acces_resp_depot_bronx.sql` |
| `ANALYSTE` | tous les dépôts, aucune donnée qui identifie directement un chauffeur ; l'année de naissance seulement ; toutes les tables de `MARTS`, tables futures comprises | analyser l'activité sans identifier personne | tests 5, 9, 13, 14, 21, 25 ; `test_acces_analyste.sql` ; `docs/capture_meme_requete_analyste.png` et `docs/capture_meme_requete_rh_paie.png` |
| `TRANSFORMER` (rôle des outils) | toutes les lignes, tout en clair ; propriétaire des tables | charger, transformer, faire tourner les tâches : s'il lisait un masque, il l'écrirait dans les tables | tests 10, 22, 23 ; `test_apres_relance_pipeline.sql`, `test_apres_taches.sql` |
| `GOUVERNANCE` | aucune donnée ; il lit seulement sa table de règles `ACCES_DEPOT` | écrire les règles (tags, politiques) sans lire les données | tests 6 et 19 ; `test_acces_gouvernance.sql` ; `docs/ACCES.md` partie 1 |
| `ACCOUNTADMIN`, `SYSADMIN` | 0 ligne des tables RH : ils les lisent par héritage de `TRANSFORMER`, mais ne figurent pas dans `ACCES_DEPOT` | administrer le compte, pas lire le personnel | tests 7, 9 bis, 15, 16 ; explication dans `docs/ACCES.md` partie 2 |

La règle d'accès vit dans la table `GOUVERNANCE.ACCES_DEPOT` : ouvrir un dépôt à un rôle est un `INSERT`, sans toucher à la politique (`snowflake/gouvernance/04_acces_depot.sql`).

### Combien de temps

| Règle | Comment elle est appliquée | Preuve |
|---|---|---|
| R1 : suppression 5 ans après la fin du contrat | `snowflake/rh/purge_rh.sql` (une fois, avec rapport) puis tâche quotidienne `MARTS.T_PURGE` (suspendue à la fin du projet, réactivable) : supprime les services puis les chauffeurs dont `end_date` est antérieure à aujourd'hui − 5 ans, dans `RAW` ; `DIM_DRIVER` et le mart sont reconstruits ensuite (`T_TABLES`). | rapport de la purge du 4 novembre 2026 : date limite 2021-11-04, 46 chauffeurs purgés, `RAW.DRIVERS` 400 → 354, `DIM_DRIVER` 354 ; 0 service concerné, car ces chauffeurs n'ont aucun service dans le relevé de janvier à mars 2025 ; `docs/capture_purge_conservation.png` |
| R2 : pas de restauration au-delà de 1 jour | `DATA_RETENTION_TIME_IN_DAYS = 1` posé explicitement sur `RAW.DRIVERS`, `RAW.DRIVER_SHIFTS`, `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY` (`snowflake/rh/conservation_rh.sql`). Le défaut du compte valait déjà 1 ; la valeur est maintenant explicite. | `INFORMATION_SCHEMA.TABLES.retention_time` = 1 pour les quatre tables (même capture). Time Travel prouvé avant : juste avant la purge, `RAW.DRIVERS` contenait 400 lignes, dont les 46 chauffeurs purgés, encore lisibles. |
| R3 : pas de fichier sur le stage | `PURGE = TRUE` dans le `COPY INTO` du chargement (`snowflake/rh/chargement_rh_2_copier.sql`) | `LIST @NYC_TAXI.RAW.RH_STAGE` vide ; 0 fichier dans `DIRECTORY(@RH_STAGE)` (même capture) |

Délai réel entre l'exécution de la purge et la disparition définitive d'une donnée dans Snowflake, en tenant compte de Time Travel et de Fail-safe : **8 jours** (1 jour de Time Travel, restaurable par vous, puis 7 jours de Fail-safe, que seul Snowflake peut utiliser et que l'on ne peut pas réduire). Pour qu'une donnée supprimée soit irrécupérable plus vite, il faudrait des tables transitoires (sans Fail-safe et avec 0 ou 1 jour de Time Travel, d'après la documentation Snowflake contrôlée le 4 novembre 2026 ; elles perdent aussi la protection contre une perte accidentelle, d'où une piste à discuter, pas une décision).

### Comment on le contrôle

| Question | Réponse | Preuve |
|---|---|---|
| Peut-on dire qui a lu ces données la semaine dernière ? | Oui : `ACCESS_HISTORY` donne les objets lus, `QUERY_HISTORY` le rôle, joints sur l'identifiant de la requête. Le relevé du 4 novembre 2026 nomme 8 lecteurs de `DIM_DRIVER` (dont les tâches, sous l'utilisateur `SYSTEM`) et ne contient pas `GOUVERNANCE`. Limites : retard jusqu'à 3 h, et seules les requêtes réussies y figurent. | `snowflake/gouvernance/06_audit.sql` ; `docs/capture_audit.png` (colonne utilisateur masquée) |
| Sait-on quand une donnée est fausse ? | Oui, pour huit règles, mesurées chaque jour par `T_QUALITE` sur `RAW` : une ligne par règle et par exécution dans `GOUVERNANCE.QUALITE_RESULTATS` (6 `ALERTE`, 2 `OK` le 4 novembre). Seule `service_rattache` est bloquante (seuil 50, 25 mesurés) : quand elle dépasse son seuil, `T_QUALITE` échoue après avoir enregistré ses résultats et `T_TABLES` ne part pas. Le contrat ne dit pas qui corrige une anomalie, ni sous quel délai. | `snowflake/rh/controles/` (8 règles), `snowflake/rh/taches_rh.sql` ; `docs/capture_taches_et_qualite.png` ; blocage démontré avec un seuil abaissé à 10 : `docs/capture_blocage_tache.png` |
| Que se passe-t-il si le rôle des outils est compromis ? | C'est la limite principale. `TRANSFORMER` lit toutes les lignes en clair, possède les tables et a reçu `APPLY` sur les trois tags : il pourrait retirer le tag `DONNEE_PERSONNELLE` d'une colonne, et le masque ne s'y appliquerait plus (non testé). Il ne possède pas les politiques, qui appartiennent à `GOUVERNANCE`. Ses lectures restent tracées par l'audit. À réduire par une authentification renforcée sur ce rôle et une revue régulière de `SHOW GRANTS`. | `docs/ACCES.md` partie 1 (« ce que cette carte permet de défaire ») ; `docs/capture_audit.png` |

### Limites connues

- Le rôle des outils voit tout en clair et peut retirer un tag : il est protégé par l'audit et par l'organisation, pas par la technique.
- `ACCOUNTADMIN` ne lit pas les données, mais peut s'attribuer le rôle `RH_PAIE` ou `TRANSFORMER`. Le garde-fou est organisationnel (revue des droits, audit), pas technique.
- Le délai réel de suppression est de 8 jours à cause du Fail-safe, que le contrat ne mentionne pas.
- `end_date` pilote la purge : un chauffeur sans date de fin n'est jamais purgé, et 5 dates de fin sont antérieures à l'embauche (règle `dates_coherentes`) sans que rien ne les corrige.
- Les dates d'embauche et de fin restent en clair : avec le dépôt, elles réduisent le nombre de candidats. L'audit ne voit que ce qui a réussi, avec un retard.
- Hors périmètre technique, non traité ici : l'information des chauffeurs, le contrat de sous-traitance avec Snowflake, la désignation du DPO, le transfert vers Londres au-delà de la décision d'adéquation (`docs/VEILLE.md`, section 5).
