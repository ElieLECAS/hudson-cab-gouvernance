# Hudson Cab Partners : gouverner l'entrepôt NYC Taxi

Projet de formation (Data Engineer). Hudson Cab Partners exploite une flotte de taxis jaunes à New York, avec trois dépôts : Bronx, Brooklyn et Queens. Son entrepôt Snowflake contient maintenant le fichier du personnel (400 chauffeurs, fictifs) et le relevé de leurs services de janvier à mars 2025. Personne ne s'est encore demandé qui avait le droit de lire ces données, ni combien de temps on pouvait les garder.

Ce dépôt répond à une seule question : qui peut voir quelle donnée, pendant combien de temps, et peut-on s'y fier ?

## Où en est le projet

| Étape | État |
|---|---|
| Veille réglementaire (`docs/VEILLE.md`) | rédigée |
| Inventaire des données personnelles (`docs/REGISTRE.md`, partie 1) | fait |
| Chargement du fichier dans `RAW`, rôle `GOUVERNANCE` et tags, catalogue des tables RH | fait (jour 1) |
| Masquage, accès par dépôt, cahier de tests (`docs/ACCES.md`) | fait (jour 2) : 25 tests sur 25 verts |
| Purge, règles de qualité, tâches planifiées, catalogue, audit, registre complet | fait (jour 3) |

Le projet est terminé : les trois tâches planifiées sont suspendues (voir « Les tâches ») et le rendu est ce dépôt, avec ses captures et ses scripts de test.

## Contenu du dépôt

- `CONTRAT_GOUVERNANCE.md` : ce que la direction impose (noms des objets, accès, durées de conservation, règles de qualité). Le contrat n'est pas réécrit ici : quand une règle pose problème, c'est signalé plus bas.
- `GUIDE_BRIEF_GOUVERNANCE.md` : les étapes du brief.
- `docs/` : la veille (`VEILLE.md`), le registre (`REGISTRE.md`), la carte des droits et le cahier de tests (`ACCES.md`), les captures (aucune valeur de personne).
- `snowflake/` : le SQL, rejouable. `00_installation.sql` crée la base, les schémas, le warehouse et le rôle des outils. `rh/` contient le chargement, la construction des tables, le catalogue, la purge, la conservation, les règles de qualité et les tâches. `gouvernance/` contient le rôle `GOUVERNANCE`, les tags, les rôles métier, les politiques de masquage et d'accès par dépôt, l'audit, et `tests/` : un script de test par rôle.
- `exemples/` : exemples fournis avec le kit, lus et adaptés, pas copiés.
- `COURS_GOUVERNANCE_SNOWFLAKE.md` et `PLAN_BRIEF_3_JOURS.md` : mes notes de cours et mon plan de travail.

## Pourquoi les fichiers CSV ne sont pas dans le dépôt

Le dépôt est public et l'historique Git garde tout, même ce qu'on supprime ensuite. Le fichier des chauffeurs est fictif, mais il a la forme d'un vrai fichier du personnel : noms, e-mails, téléphones, dates de naissance, numéros de licence. Il est traité comme un vrai. Le dossier `data/` est donc ignoré par Git, et les captures d'écran du dépôt n'affichent aucune valeur en clair du fichier. Pour rejouer le projet, il faut récupérer les deux CSV dans le kit du brief et les placer dans `data/`.

## Chargement des données

Les deux CSV sont chargés dans `NYC_TAXI.RAW` en trois temps, par `snowflake/rh/chargement_rh_1_preparer.sql` puis `chargement_rh_2_copier.sql`, avec le rôle `TRANSFORMER`.

- **Le format de fichier** (`CSV_RH`) dit à Snowflake comment lire un CSV : on saute la ligne d'en-tête, les guillemets entourent les champs, et les espaces ne sont pas retirés. `RAW` doit rester une copie fidèle du fichier : les erreurs (un dépôt écrit `BRONX ` avec un espace, par exemple) sont corrigées plus tard, dans `STAGING`.
- **Le stage** (`RH_STAGE`) est un espace de dépôt dans Snowflake. J'y ai déposé les deux fichiers depuis Snowsight. `LIST` en montrait deux, avec la même taille et la même somme de contrôle que les fichiers locaux.
- **`COPY INTO`** lit les fichiers du stage et remplit les tables. Il convertit les colonnes de dates et de nombres au passage, et ajoute le nom du fichier source et l'heure du chargement. Avec `ON_ERROR = ABORT_STATEMENT`, une seule ligne illisible annule tout le chargement du fichier, au lieu de laisser une table à moitié remplie.
- **`PURGE = TRUE`** retire chaque fichier du stage une fois copié. C'est la règle R3 du contrat : le fichier RH ne reste pas dans Snowflake après le chargement. `LIST` est vide ensuite.

Résultat : 400 chauffeurs et 25 951 services dans `RAW`, comme attendu. Relancer `chargement_rh_2_copier.sql` avec un stage vide échoue sur « Remote file … was not found », puisque `FILES = ('drivers.csv')` désigne un fichier qui n'est plus là. Je n'ai pas testé ce que fait `COPY INTO` quand on redépose le même fichier.

## Gouvernance

### Le droit applicable

Le RGPD s'applique à ces données. Depuis cette année, leur gestion est confiée à Hudson Cab Europe, à Paris. C'est elle qui décide de ce qu'on en fait : elle est responsable du traitement, et l'article 3, paragraphe 1, suffit à rendre le règlement applicable. Que les chauffeurs travaillent à New York ne change rien, car cet article regarde où est établi le responsable, pas où se trouvent les personnes. Snowflake héberge les données pour son compte : c'est un sous-traitant. L'autorité de contrôle compétente est la CNIL. Le détail, avec les articles et les pages citées, est dans `docs/VEILLE.md`.

### Écarts entre le contrat et les textes

Le contrat a été écrit avant le transfert de la gestion à Paris. Je ne le modifie pas, mais plusieurs points ne collent pas avec les textes :

- **R1, suppression 5 ans après la fin du contrat.** La durée ressemble à ce que la CNIL donne comme exemple pour le registre du personnel et la paie, mais ces exemples viennent du droit du travail français, et les contrats sont new-yorkais. La CNIL distingue aussi la base active de l'archivage : après le départ d'un chauffeur, ses données devraient sortir de la base de travail et n'être lisibles que par un accès restreint. Dans le contrat, les mêmes rôles continuent de tout voir pendant 5 ans. Enfin, 46 chauffeurs du fichier sont partis depuis plus de 5 ans : leurs données auraient déjà dû être supprimées. C'est l'écart que je retiens comme principal.
- **R2, Time Travel limité à 1 jour.** Snowflake garde ensuite les données 7 jours de plus (Fail-safe), sans qu'on puisse l'éviter ni y accéder soi-même. Une donnée supprimée n'est donc définitivement effacée qu'au bout de 8 jours. Le contrat ne mentionne que le premier jour.
- **R3, fichier retiré du stage après chargement.** Conforme sur le principe. Reste hors du contrat les copies locales des CSV sur les postes, à supprimer en fin de projet.
- **Matrice des accès.** Plusieurs points sont à justifier : le service paie voit la date de naissance complète et le numéro de licence ; les responsables de dépôt voient aussi les chauffeurs partis ; `driver_id`, visible de tous, est un pseudonyme et non une donnée anonyme ; l'analyste lit toutes les tables de `MARTS`, y compris celles qui seront créées plus tard, sans qu'on sache si elles contiendront des données personnelles.
- **Règles de qualité.** Sept règles sur huit se contentent d'alerter. Le contrat ne dit pas qui corrige une anomalie ni sous quel délai, alors que le RGPD demande de corriger ou d'effacer les données inexactes sans tarder.
- **Ce que le contrat ne dit pas.** Quatre points. La région du compte Snowflake : `AWS_EU_WEST_2`, c'est-à-dire Londres. Le Royaume-Uni est hors de l'Union, donc l'hébergement est un transfert ; il est couvert par la décision d'adéquation de la Commission, renouvelée en décembre 2025 et valable jusqu'au 27 décembre 2031, à surveiller. Le contrat de sous-traitance avec Snowflake. L'information des chauffeurs sur le traitement. Le registre des traitements.

Les questions que la veille ne peut pas trancher seule (durées new-yorkaises, rôle exact de l'entité américaine, délai de 8 jours, garanties sur la région) sont listées à la fin de `docs/VEILLE.md`, avec la personne à qui les poser.

### Ce qui est protégé et comment

Six mécanismes, chacun écrit dans un fichier SQL rejouable :

- **Les rôles** (`snowflake/gouvernance/01_gouvernance.sql`, `02_roles_metier.sql`) : chaque règle est portée par un rôle, jamais par un utilisateur. `GOUVERNANCE` écrit les règles et ne lit aucune donnée ; `TRANSFORMER` charge et transforme ; quatre rôles métier ne lisent que `MARTS`. `ACCOUNTADMIN` ne lit pas les données du personnel.
- **Les tags** (`rh/catalogue/`) : `DONNEE_PERSONNELLE` sur chaque colonne qui décrit une personne (y compris `driver_name`, colonne calculée), `SENSIBILITE` et `DUREE_CONSERVATION` sur chaque table. Les descriptions de colonnes et de tables sont dans les mêmes fichiers, et la vue `GOUVERNANCE.V_CATALOGUE` les présente, une ligne par colonne.
- **Le masquage** (`03_masquage.sql`) : deux politiques, une pour le texte, une pour les dates, attachées au tag `DONNEE_PERSONNELLE`. Toute colonne taguée, aujourd'hui ou demain, est protégée.
- **Le filtre par dépôt** (`04_acces_depot.sql`) : une politique d'accès par ligne qui lit la table `GOUVERNANCE.ACCES_DEPOT`. Ajouter un dépôt à un rôle est un `INSERT`, sans toucher à la politique.
- **La conservation** (`rh/purge_rh.sql`, `rh/conservation_rh.sql`) : purge à 5 ans après la fin du contrat, rétention de 1 jour, aucun fichier sur le stage.
- **Le contrôle** (`rh/controles/`, `rh/taches_rh.sql`, `gouvernance/06_audit.sql`) : huit règles de qualité mesurées chaque jour, et une requête qui dit quels rôles ont lu `DIM_DRIVER`.

Ce que chaque rôle voit de `DIM_DRIVER` et de `MART_DRIVER_MONTHLY` :

| Rôle | Lignes visibles | Nom, prénom, `driver_name` | Téléphone | E-mail | Date de naissance | Licence TLC | `driver_id` |
|---|---|---|---|---|---|---|---|
| `RH_PAIE` | tous les dépôts | clair | clair | clair | complète | claire | clair |
| `RESP_DEPOT_QUEENS` | Queens | clair | clair | `*****` | `NULL` | `*****` | clair |
| `RESP_DEPOT_BRONX` | Bronx | clair | clair | `*****` | `NULL` | `*****` | clair |
| `ANALYSTE` | tous les dépôts | `*****` | `*****` | `*****` | 1er janvier de l'année | `*****` | clair |
| `TRANSFORMER` | toutes | clair | clair | clair | complète | claire | clair |
| `GOUVERNANCE`, `ACCOUNTADMIN`, `SYSADMIN` | aucune (`GOUVERNANCE` : accès refusé ; les deux autres : 0 ligne) | | | | | | |

Les valeurs de ce tableau sont celles du cahier de tests (`docs/ACCES.md`, partie 2), relevées avec chaque rôle. La carte des droits (qui possède quoi, qui peut faire quoi, avec quel droit) est dans la partie 1 du même fichier.

### Choix techniques

#### Masquer ou supprimer, colonne par colonne

Supprimer une colonne la retire pour **tous** les rôles, y compris ceux qui en ont besoin : `DIM_DRIVER` sert à la fois la paie, les responsables de dépôt et l'analyste. Je supprime donc une colonne seulement si personne n'en a besoin. Sinon je la masque, ce qui laisse chaque rôle voir ce que le contrat lui donne. Les valeurs masquées sont `*****` pour un texte et `NULL` pour une date (sauf l'analyste, qui voit le 1er janvier de l'année de naissance). Le masquage est porté par le tag `DONNEE_PERSONNELLE`, posé dans le catalogue, et attaché au tag : toute colonne taguée, aujourd'hui ou plus tard, est protégée.

| Colonne | Qui la voit en clair | Décision | Raison |
|---|---|---|---|
| `driver_id` | tous les rôles métier | visible de tous | C'est un pseudonyme : il reste une donnée personnelle, mais le contrat le veut visible pour compter et joindre les tables sans nommer personne. La politique prévoit l'exception. |
| `first_name`, `last_name`, `driver_name` | paie, responsables de dépôt | masquer pour l'analyste | L'analyste n'a pas besoin de savoir qui est un chauffeur. `driver_name` est un nom recopié dans une table d'activité : il est masqué comme les deux colonnes dont il vient. |
| `email` | paie seulement | masquer pour tous les autres | Seule la paie joint les salariés par e-mail. L'analyste n'en a pas besoin, même masqué : une vue sans cette colonne aurait été possible, mais c'est un objet de plus à maintenir, alors que le masque ne montre rien. |
| `phone` | paie, responsables de dépôt | masquer pour l'analyste | Les responsables appellent les chauffeurs de leur dépôt. |
| `birth_date` | paie : date complète | masquer ; l'analyste voit l'année seulement | Le contrat l'autorise pour l'analyse par tranche d'âge. Une date masquée reste une date : l'analyste lit le 1er janvier de l'année de naissance, les responsables lisent `NULL`. |
| `tlc_license_number` | paie | masquer pour tous les autres | Numéro officiel, identifiant direct. Je le garde pour la paie parce que le contrat lui donne « tout », mais je n'ai pas la preuve qu'elle en a besoin : si ce n'est pas le cas, il faudrait le supprimer (principe de minimisation, art. 5 §1 c du RGPD). Question posée dans `docs/VEILLE.md`. |
| `hire_date`, `end_date` | tous les rôles métier | laisser en clair | Aucune valeur du tag ne leur correspond, et ce ne sont pas des identifiants directs. Elles servent à l'ancienneté, à `is_active` et à la règle R1. Avec le dépôt, elles réduisent le nombre de candidats : c'est un risque que j'accepte et que je note dans les limites. |
| `is_active`, `tenure_years` | tous les rôles métier | laisser en clair | Colonnes calculées à partir des deux dates ci-dessus, avec le même raisonnement. Elles révèlent seulement si le contrat est terminé et depuis quand. |
| `depot` | tous les rôles métier | en clair | C'est la colonne qui filtre les lignes visibles par dépôt. |
| `nb_shifts`, `hours_worked`, `trips_count`, `revenue_usd` (mart) | tous les rôles métier | en clair | Ce sont des mesures d'activité, personnelles seulement par `driver_id`. Une fois le nom masqué, l'analyste agrège sans identifier. |

Aucune colonne n'est supprimée. Deux pistes restent ouvertes : retirer `tlc_license_number` si la paie n'en a pas besoin, et retirer `driver_name` de `MART_DRIVER_MONTHLY` pour ne plus recopier un nom dans une table d'activité (la jointure avec `DIM_DRIVER` suffirait). J'ai gardé `driver_name` parce que le contrat et le cahier de tests l'attendent.

#### Le masquage et le filtre

- **Par tag, pas colonne par colonne** : le catalogue pilote la sécurité. Une politique de masquage par type de colonne (texte, date), attachée au tag : `MASK_TEXTE` et `MASK_DATE`. Une politique renvoie le type qu'elle reçoit, donc une date masquée reste une date.
- **`CURRENT_ROLE()`, pas `IS_ROLE_IN_SESSION`** : la politique regarde le rôle actif. Avec `IS_ROLE_IN_SESSION`, un administrateur qui hérite d'un rôle serait traité comme ce rôle. Ici, `ACCOUNTADMIN` n'a rien dans `ACCES_DEPOT` : il lit les tables par héritage, mais voit 0 ligne (tests 7, 9 bis, 15, 16).
- **Refus par défaut** : le dernier cas du masque est `*****` (ou `NULL`). Un rôle qui n'est pas cité ne voit jamais une valeur par oubli.
- **L'exception `driver_id`** : la colonne porte le tag comme les autres, mais le contrat veut qu'elle reste visible. La politique la repère par la valeur du tag (`identifiant_interne`).
- **`TRANSFORMER` voit en clair et figure dans `ACCES_DEPOT`** : sinon le pipeline recopierait des masques dans `DIM_DRIVER`, ou reconstruirait le mart sans aucune ligne ni nom, sans erreur. Le test 10 le vérifie après chaque relance.
- **`'*'` pour « tous les dépôts »** dans `ACCES_DEPOT`.
- **La politique par ligne est aussi attachée à `RAW`** : le contrat range `RAW.DRIVERS` et `RAW.DRIVER_SHIFTS` parmi les tables du domaine RH, et donne « aucune ligne » à `ACCOUNTADMIN`.
- **`INSERT OVERWRITE`, jamais `CREATE OR REPLACE TABLE`** sur les tables RH : une table recréée perd ses tags, ses descriptions et ses politiques. Les politiques se retrouvent identiques après chaque exécution des tâches (`rh/` et test 12 du cahier).
- **Des scripts rejouables** : `IF NOT EXISTS` pour les objets, `ALTER … SET BODY` pour changer une politique attachée, un bloc qui tolère « déjà attaché », `DROP ALL ROW ACCESS POLICIES` puis `ADD`.

#### La conservation

- **Critère de purge** : `end_date` antérieure à aujourd'hui moins 5 ans. Un chauffeur en poste (`end_date` vide) n'est jamais purgé. Le résultat dépend de la date d'exécution : le 4 novembre 2026, la limite est le 4 novembre 2021 et 46 chauffeurs sont concernés (aucune date de fin du fichier n'est proche de la limite, ce nombre est stable de fin septembre à mi-décembre).
- **Les services d'un chauffeur parti** : le contrat dit que R1 s'applique partout où la donnée a été copiée. La purge supprime donc ses services dans `RAW.DRIVER_SHIFTS`, avant le chauffeur (la liste des chauffeurs à purger se lit dans `RAW.DRIVERS`). Dans ce fichier, les 46 chauffeurs n'ont aucun service (il couvre janvier à mars 2025) : 0 ligne supprimée, la règle reste écrite pour les prochains chargements.
- **`DIM_DRIVER` et le mart ne se purgent pas à la main** : ils sont reconstruits depuis `RAW` par `T_TABLES`. Après la purge : `DIM_DRIVER` 354, `MART_DRIVER_MONTHLY` 914.
- **Les services orphelins** (25, des chauffeurs inconnus) ne sont pas purgés : R1 ne les concerne pas. La règle de qualité `service_rattache` les mesure.
- **Un fichier complet rechargé** (par exemple depuis 2005) ramènerait les anciens chauffeurs dans `RAW` : la purge doit donc tourner après chaque chargement, d'où une tâche quotidienne.
- **Durée de conservation par table** (tag `DUREE_CONSERVATION`) : `RAW.DRIVERS` et `DIM_DRIVER` « 5 ans après la fin du contrat » ; `RAW.DRIVER_SHIFTS` et `MART_DRIVER_MONTHLY` « 5 ans après la fin du contrat du chauffeur » ; `DIM_DEPOT` sans limite (référentiel de l'entreprise).
- **Time Travel d'abord, rétention ensuite** : juste après la purge, `RAW.DRIVERS` pouvait encore être lue avec ses 400 lignes, dont les 46 chauffeurs supprimés. J'ai fixé ensuite `DATA_RETENTION_TIME_IN_DAYS = 1` sur les quatre tables. Le défaut du compte valait déjà 1 : la valeur est maintenant explicite. Le délai réel de disparition est de 8 jours, à cause des 7 jours de Fail-safe, qu'on ne peut pas réduire.

#### La qualité des données

Les huit règles du contrat sont mesurées sur `RAW`, chacune par une requête qui renvoie un seul nombre (`rh/controles/`). `T_QUALITE` les enregistre chaque jour dans `GOUVERNANCE.QUALITE_RESULTATS` : une ligne par règle et par exécution, `OK` si le nombre est sous le seuil, `ALERTE` sinon.

| Règle | Énoncé | Seuil | Gravité | Mesure du 4 novembre 2026 |
|---|---|---|---|---|
| `licence_unique` | un numéro de licence n'appartient qu'à un chauffeur | 0 | avertissement | 4, `ALERTE` |
| `telephone_renseigne` | chaque chauffeur en poste a un téléphone | 5 % des chauffeurs en poste (15) | avertissement | 12, `OK` |
| `email_valide` | l'e-mail contient un `@` | 0 | avertissement | 7, `ALERTE` |
| `dates_coherentes` | pas d'embauche future, pas de fin avant l'embauche | 0 | avertissement | 8, `ALERTE` |
| `depot_connu` | dépôt écrit exactement `Bronx`, `Brooklyn` ou `Queens` | 0 | avertissement | 9, `ALERTE` |
| `service_rattache` | chaque service appartient à un chauffeur connu | 50 services | **bloquant** | 25, `OK` |
| `service_unique` | un identifiant de service n'apparaît qu'une fois | 0 | avertissement | 18, `ALERTE` |
| `duree_plausible` | un service ne dure pas plus de 16 heures | 0 | avertissement | 14, `ALERTE` |

Une règle d'avertissement enregistre une ligne `ALERTE` et les tâches continuent. La règle bloquante enregistre son résultat, **puis** lève une erreur : `T_QUALITE` échoue et `T_TABLES` ne part pas. J'ai prouvé ce blocage en abaissant le seuil de `service_rattache` à 10, puis en le remettant à 50 (`docs/capture_blocage_tache.png`).

#### Les tâches

`MARTS.T_PURGE` (racine, chaque jour à 6 h, heure de Paris) → `MARTS.T_QUALITE` → `MARTS.T_TABLES`. On purge, on contrôle, et on ne reconstruit les tables que si le contrôle est passé. Les tâches tournent avec le rôle `TRANSFORMER`, qui lit en clair et figure dans `ACCES_DEPOT`. Le graphe est dans `docs/capture_graphe_taches.png`. Les trois tâches ont été suspendues le 4 novembre 2026 (`snowflake/rh/suspendre_taches.sql`), parce qu'une tâche activée consomme des crédits chaque jour : l'état `suspended` des trois a été vérifié avec `SHOW TASKS`. Pour les réactiver : `SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('NYC_TAXI.MARTS.T_PURGE');` ou rejouer `taches_rh.sql`.

### Ordre d'exécution

Chaque fichier se colle dans une feuille Snowsight et se lance en entier. Chacun commence par `USE SECONDARY ROLES NONE;` et prend lui-même son rôle ; le rôle indiqué est celui qui l'exécute. Prérequis : un compte Snowflake **Enterprise** (masquage, accès par ligne, `ACCESS_HISTORY`) et les deux CSV du kit dans `data/`.

| # | Fichier | Rôle | Ce que ça fait |
|---|---|---|---|
| 1 | `snowflake/00_installation.sql` | `ACCOUNTADMIN` | warehouse, base, schémas `RAW`, `STAGING`, `MARTS`, rôle `TRANSFORMER` |
| 2 | `snowflake/rh/chargement_rh_1_preparer.sql` | `TRANSFORMER` | format de fichier, stage `RH_STAGE`, tables `RAW` |
| 3 | dépôt des deux CSV sur `@NYC_TAXI.RAW.RH_STAGE` depuis Snowsight (`LIST` : 2 fichiers) | `TRANSFORMER` | |
| 4 | `snowflake/rh/chargement_rh_2_copier.sql` | `TRANSFORMER` | `COPY INTO` avec `PURGE = TRUE` : 400 chauffeurs, 25 951 services, stage vide |
| 5 | `snowflake/rh/00_tables_rh.sql` | `TRANSFORMER` | tables de `MARTS`, vides |
| 6 | `snowflake/rh/staging/stg_rh__drivers.sql`, puis `stg_rh__driver_shifts.sql` | `TRANSFORMER` | vues de nettoyage (`STG_RH__DRIVER_SHIFTS` : 25 933 lignes) |
| 7 | `snowflake/rh/marts/dim_depot.sql`, `dim_driver.sql`, `mart_driver_monthly.sql` | `TRANSFORMER` | `DIM_DEPOT` 3, `DIM_DRIVER` 400, `MART_DRIVER_MONTHLY` 914 |
| 8 | `snowflake/gouvernance/01_gouvernance.sql` | `ACCOUNTADMIN`, puis `GOUVERNANCE` | rôle `GOUVERNANCE`, schéma, 3 tags, `QUALITE_RESULTATS`, droits |
| 9 | `snowflake/gouvernance/modele_catalogue_dim_depot.sql`, puis `snowflake/rh/catalogue/catalogue_*.sql` (4 fichiers) | `TRANSFORMER` | descriptions et tags des tables |
| 10 | `snowflake/gouvernance/02_roles_metier.sql` | `ACCOUNTADMIN` | `RH_PAIE`, `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX`, `ANALYSTE` et leurs droits de lecture |
| 11 | `snowflake/gouvernance/03_masquage.sql`, puis `04_acces_depot.sql` | `GOUVERNANCE` | politiques de masquage, table `ACCES_DEPOT`, politique par ligne |
| 12 | `snowflake/rh/purge_rh.sql`, puis `marts/dim_driver.sql` et `marts/mart_driver_monthly.sql`, `preuves_purge.sql`, `conservation_rh.sql` | `TRANSFORMER` | purge R1 (même session pour les quatre derniers), reconstruction, preuve du Time Travel, rétention R2, stage R3 : `DIM_DRIVER` 354 |
| 13 | `snowflake/rh/catalogue/v_catalogue.sql` | `TRANSFORMER` | vue `GOUVERNANCE.V_CATALOGUE` (24 colonnes) |
| 14 | `snowflake/rh/taches_rh.sql` | `TRANSFORMER` | les trois tâches, activées et lancées une fois |
| 15 | `snowflake/gouvernance/06_audit.sql` | `ACCOUNTADMIN` | qui a lu `DIM_DRIVER` (retard possible jusqu'à 3 h) |
| 16 | `snowflake/rh/suspendre_taches.sql` | `TRANSFORMER` | suspend les trois tâches en fin de projet |

Les tests sont dans `snowflake/gouvernance/tests/` : un script par rôle (`test_acces_<rôle>.sql`), plus `test_apres_relance_pipeline.sql`, `test_12_politiques_attachees.sql`, `test_apres_taches.sql` et `test_v_catalogue.sql`. Chacun renvoie une table, sans afficher de valeur de personne. `snowflake/rh/demo_blocage_tache.sql` rejoue le blocage de la règle bloquante.

Pour recharger un fichier complet : redéposer les CSV (étape 3), relancer l'étape 4, puis exécuter les tâches (`EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;`) ou attendre 6 h.

### Limites connues

- **Le rôle des outils voit tout en clair** et possède les tables. Il a reçu `APPLY` sur les trois tags : il pourrait retirer `DONNEE_PERSONNELLE` d'une colonne, et le masque ne s'y appliquerait plus (non testé). Il ne possède pas les politiques. Ses lectures sont tracées par l'audit ; le reste est une question d'authentification et de revue des droits.
- **`ACCOUNTADMIN` ne lit pas les données, mais peut s'attribuer un autre rôle** (`RH_PAIE`, `TRANSFORMER`) et en voir. Le garde-fou est organisationnel (revue de `SHOW GRANTS`, audit), pas technique.
- **Fail-safe** : une donnée supprimée n'a réellement disparu qu'au bout de 8 jours (1 + 7). Les tables transitoires sont une piste : elles n'ont pas de Fail-safe, et leur Time Travel est de 0 ou 1 jour (documentation Snowflake, page *Working with Temporary and Transient Tables*, contrôlée le 4 novembre 2026). Je ne l'ai pas appliquée : une table transitoire perd aussi la protection contre une perte accidentelle.
- **Les dates en clair** (`hire_date`, `end_date`, `is_active`, `tenure_years`) : aucune valeur du tag ne leur correspond (liste fermée par le contrat). Avec le dépôt, elles réduisent le nombre de candidats. Je les laisse parce qu'elles ne sont pas identifiantes seules et que la règle R1 en a besoin.
- **`tlc_license_number`** : gardé en clair pour la paie parce que le contrat lui donne « tout ». Si elle n'en a pas l'usage, il faudrait le supprimer (minimisation, art. 5 §1 c du RGPD). C'est une proposition, pas une décision.
- **`driver_name` dans `MART_DRIVER_MONTHLY`** recopie un nom dans une table d'activité. Je le garde (masqué par le tag) parce que le contrat et le cahier de tests l'attendent. On pourrait le retirer et passer par la jointure avec `DIM_DRIVER`.
- **La purge repose sur `end_date`** : un chauffeur sans date de fin n'est jamais purgé, et 5 dates de fin sont antérieures à l'embauche (règle `dates_coherentes`) sans que rien ne les corrige. Rien ne distingue la base active de l'archivage intermédiaire, que la CNIL recommande.
- **Qualité** : sept règles sur huit se contentent d'alerter. Le contrat ne dit pas qui corrige une anomalie ni sous quel délai.
- **Dans `STAGING`**, quand un identifiant de service est en double, la ligne gardée n'est pas déterminée (même heure de chargement). Les volumes sont les mêmes dans les deux cas.
- **L'audit** ne voit que les requêtes qui ont réussi, avec un retard pouvant atteindre 3 heures.
- **Relancer le chargement avec un stage vide échoue** (« Remote file … was not found ») : la clause `FILES` désigne un fichier que `PURGE = TRUE` a retiré. Je n'ai pas testé le cas d'un fichier redéposé. Le commentaire du kit (« relancé, ce fichier ne charge rien de plus ») n'est exact que dans ce cas.
- **Le kit** décrit `GOUVERNANCE` comme voyant les tables sans les lire : dans mes essais, `SHOW TABLES` était vide pour ce rôle avec `USAGE` sur le schéma. Il peut quand même attacher une politique à une table qu'il ne voit pas, grâce aux droits `APPLY` sur le compte.
- **Une erreur utile** : ma première version de `T_QUALITE` échouait avec « INTO clause is not allowed in this context », parce que j'avais mis une sous-requête dans un `SELECT … INTO` à l'intérieur d'un bloc de script. L'échec est resté dans l'historique des tâches.
- **Hors périmètre technique**, non traité : l'information des chauffeurs sur le traitement, le contrat de sous-traitance avec Snowflake, la désignation du DPO, et la suite du transfert vers Londres au-delà de la décision d'adéquation (`docs/VEILLE.md`, section 5).
