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

Pour chaque colonne personnelle : la liste des tables et des vues de l'entrepôt où elle se retrouve, y compris sous une autre forme (colonne renommée, colonne calculée). À compléter au fil des trois jours. État à la fin du jour 1, relevé dans les SQL fournis (`snowflake/rh/`).

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
| toutes les colonnes de `RAW` | historique Time Travel (1 jour) puis Fail-safe (7 jours) des tables ci-dessus | toutes | copies conservées par Snowflake après suppression ou modification (voir `VEILLE.md`, fiche 6) |

Hors de l'entrepôt : les copies locales des CSV (poste de travail, téléchargements) sont des copies supplémentaires, à supprimer à la fin du brief.

### Ce qui a surpris

- **Le nom du chauffeur s'est glissé dans une table d'activité.** `MART_DRIVER_MONTHLY` est une table de chiffres (services, heures, recette), lue par `ANALYSTE`, et elle contient pourtant `driver_name`, calculée à partir du prénom et du nom. Cette colonne n'est pas dans le fichier d'origine : elle doit être cataloguée et protégée comme les autres.
- **Des colonnes d'apparence neutre deviennent personnelles.** Heures, courses et recette ne disent rien d'une personne seules ; avec `driver_id`, elles mesurent le travail de quelqu'un. Il en va de même pour `is_active` et `tenure_years`, qui cachent `end_date` et `hire_date`.
- **Des données qui n'auraient pas dû rester dans le fichier.** À la date du 3 novembre 2026, 46 chauffeurs sont partis depuis plus de 5 ans : leurs données auraient dû être supprimées (règle R1). Par ailleurs, la date de naissance complète et le numéro de licence ne sont attendus que par `RH_PAIE` dans la matrice : tous les autres rôles n'en ont pas besoin.

---

## Partie 2 — Fiche de registre (jour 3)

Le registre des activités de traitement décrit ce qu'une organisation fait des données personnelles qu'elle détient. Cette fiche en est une version réduite, limitée à ce qu'un Data Engineer peut renseigner et prouver. La trame complète est celle de la CNIL (lien dans les ressources).

Chaque réponse de la colonne de droite doit pouvoir être vérifiée dans l'entrepôt : indiquez la requête ou le fichier qui le prouve.

### Le traitement

| Rubrique | Réponse |
|---|---|
| Nom du traitement | |
| Finalité : à quoi servent ces données | |
| Personnes concernées | |
| Service responsable des données | |

### Les données

| Catégorie de données | Colonnes concernées | Tables où elles se trouvent |
|---|---|---|
| Identité | | |
| Coordonnées | | |
| Vie professionnelle | | |

### Qui y accède

| Rôle | Ce qu'il voit | Pourquoi il en a besoin | Preuve (requête ou test) |
|---|---|---|---|
| | | | |

### Combien de temps

| Règle | Comment elle est appliquée | Preuve |
|---|---|---|
| R1 : suppression 5 ans après la fin du contrat | | |
| R2 : pas de restauration au-delà de 1 jour | | |
| R3 : pas de fichier sur le stage | | |

Délai réel entre l'exécution de la purge et la disparition définitive d'une donnée dans Snowflake, en tenant compte de Time Travel et de Fail-safe : ______ jours.

### Comment on le contrôle

| Question | Réponse | Preuve |
|---|---|---|
| Peut-on dire qui a lu ces données la semaine dernière ? | | |
| Sait-on quand une donnée est fausse ? | | |
| Que se passe-t-il si le rôle des outils est compromis ? | | |

### Limites connues

Ce que votre mise en œuvre ne couvre pas : deux ou trois lignes, sans détour.
