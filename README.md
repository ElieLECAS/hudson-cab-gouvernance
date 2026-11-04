# Hudson Cab Partners : gouverner l'entrepôt NYC Taxi

Projet de formation (Data Engineer). Hudson Cab Partners exploite une flotte de taxis jaunes à New York, avec trois dépôts : Bronx, Brooklyn et Queens. Son entrepôt Snowflake contient maintenant le fichier du personnel (400 chauffeurs, fictifs) et le relevé de leurs services de janvier à mars 2025. Personne ne s'est encore demandé qui avait le droit de lire ces données, ni combien de temps on pouvait les garder.

Ce dépôt répond à une seule question : qui peut voir quelle donnée, pendant combien de temps, et peut-on s'y fier ?

## Où en est le projet

| Étape | État |
|---|---|
| Veille réglementaire (`docs/VEILLE.md`) | rédigée |
| Inventaire des données personnelles (`docs/REGISTRE.md`, partie 1) | fait |
| Chargement du fichier dans `RAW`, rôle `GOUVERNANCE` et tags, catalogue des tables RH | fait (jour 1) |
| Masquage, accès par dépôt, tests (`docs/ACCES.md`) | à faire |
| Purge, qualité, tâches planifiées, audit, registre complet | à faire |

Ce fichier est complété au fil du projet. Les sections marquées « à compléter » correspondent aux étapes qui ne sont pas encore faites.

## Contenu du dépôt

- `CONTRAT_GOUVERNANCE.md` : ce que la direction impose (noms des objets, accès, durées de conservation, règles de qualité). Le contrat n'est pas réécrit ici : quand une règle pose problème, c'est signalé plus bas.
- `GUIDE_BRIEF_GOUVERNANCE.md` : les étapes du brief.
- `docs/` : la veille, le registre, la carte des accès, les captures.
- `snowflake/` : le SQL, rejouable. `00_installation.sql` crée la base, les schémas, le warehouse et le rôle des outils. `rh/` contient le chargement et la construction des tables. `gouvernance/` recevra les rôles, les tags et les politiques.
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

À compléter. Seront décrits ici, colonne par colonne : ce qui est masqué, ce qui est supprimé, et pourquoi.

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

À compléter : purge des services d'un chauffeur parti, durée de conservation par table.

### Ordre d'exécution

À compléter une fois les scripts écrits et rejoués de bout en bout.

### Limites connues

À compléter en fin de projet.
