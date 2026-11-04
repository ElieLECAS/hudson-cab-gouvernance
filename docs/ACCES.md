# Les accès — carte des droits et cahier de tests

Copier ce fichier sous le nom `docs/ACCES.md`.

- **Partie 1, jours 1 et 2** : la carte des droits, complétée au fur et à mesure que vous créez rôles et objets ;
- **Partie 2, jour 2** : le cahier de tests, « attendu » écrit avant les politiques, « obtenu » après.

---

## Partie 1 — Carte des droits

À compléter du jour 1 au jour 2. Dans Snowflake, faire une action demande d'être propriétaire de l'objet ou d'avoir reçu un privilège précis. Cette carte vous évite de chercher, à chaque erreur `Insufficient privileges`, quel droit manque et à qui.

Vérifiez chaque ligne dans la documentation des privilèges (ressources du jour 2), puis avec `SHOW GRANTS TO ROLE …`.

### Qui possède quoi

Le propriétaire d'un objet est le rôle qui l'a créé.

| Objet | Propriétaire |
|---|---|
| Tables de `RAW` et de `MARTS` | le rôle des outils |
| Schéma `GOUVERNANCE` | `GOUVERNANCE` : créé par `ACCOUNTADMIN`, qui lui en a donné la propriété (`GRANT OWNERSHIP … COPY CURRENT GRANTS`). Vérifié avec `SHOW GRANTS TO ROLE GOUVERNANCE`. |
| Tags | `GOUVERNANCE`, qui les a créés. Vérifié (3 lignes `OWNERSHIP` sur `TAG`). |
| Politiques de masquage | à remplir au jour 2. Attendu : `GOUVERNANCE`, qui les créera dans son schéma. |
| Politique d'accès par ligne | à remplir au jour 2. Attendu : `GOUVERNANCE`. |
| Table `ACCES_DEPOT` | à remplir au jour 2. Attendu : `GOUVERNANCE`. |
| Table `QUALITE_RESULTATS` | `GOUVERNANCE`, qui l'a créée. Vérifié (`OWNERSHIP` sur `TABLE`). |
| Vue `V_CATALOGUE` | à remplir au jour 3. Attendu : `TRANSFORMER`, qui la crée dans le schéma `GOUVERNANCE` avec `CREATE VIEW`. |

### Qui fait quoi, avec quel droit

| Action | Rôle qui la fait | Privilège nécessaire | Accordé par |
|---|---|---|---|
| Créer un tag | `GOUVERNANCE` | `CREATE TAG` sur le schéma, ou en être propriétaire : ici `OWNERSHIP` du schéma `GOUVERNANCE` | `ACCOUNTADMIN` |
| Poser un tag sur une colonne de `DIM_DRIVER` | `TRANSFORMER` | `APPLY` sur le tag posé, `USAGE` sur le schéma `GOUVERNANCE`, et être propriétaire de la table. Les droits sont vérifiés (`SHOW GRANTS TO ROLE TRANSFORMER`) ; la pose elle-même sera vérifiée au catalogue. | `GOUVERNANCE` (`APPLY` et `USAGE`) ; la propriété de la table vient de la création par `TRANSFORMER` |
| Créer une politique de masquage | `GOUVERNANCE` | `OWNERSHIP` du schéma `GOUVERNANCE` (à vérifier au jour 2) | `ACCOUNTADMIN` |
| Attacher une politique de masquage à un tag | `GOUVERNANCE` | `APPLY MASKING POLICY` sur le compte (à vérifier au jour 2) | `ACCOUNTADMIN` |
| Ajouter une politique d'accès par ligne à une table | `GOUVERNANCE` | `APPLY ROW ACCESS POLICY` sur le compte (à vérifier au jour 2) | `ACCOUNTADMIN` |
| Écrire une ligne dans `QUALITE_RESULTATS` | `TRANSFORMER` | `INSERT` (et `SELECT` pour relire) sur la table, `USAGE` sur le schéma. Vérifié. | `GOUVERNANCE` |
| Lire `DIM_DRIVER` | `RH_PAIE`, `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX`, `ANALYSTE` | `SELECT` sur la table, `USAGE` sur le warehouse, la base et le schéma `MARTS`. Vérifié (7 droits actuels par rôle, aucun sur `RAW` ni `STAGING`). | `02_roles_metier.sql`, exécuté par `ACCOUNTADMIN` ; Snowflake enregistre `TRANSFORMER` comme donneur du `SELECT`, car il possède la table |
| Lire une table de `MARTS` créée plus tard | `ANALYSTE` | `SELECT ON FUTURE TABLES IN SCHEMA MARTS` : droit « futur », 2 pour ce rôle (tables de `MARTS`, vues de `GOUVERNANCE`), 1 pour les trois autres (vues de `GOUVERNANCE`). Vérifié avec `SHOW FUTURE GRANTS`. | `ACCOUNTADMIN` |
| Lire `V_CATALOGUE` (jour 3) | les 4 rôles métier | `USAGE` sur le schéma `GOUVERNANCE` et `SELECT` sur les vues futures du schéma | `GOUVERNANCE` est enregistré comme donneur de `USAGE` (il possède le schéma) |
| Exécuter une requête | chaque rôle | `USAGE` sur le warehouse `NYC_TAXI_WH`. Vérifié pour `TRANSFORMER` et `GOUVERNANCE`. | `ACCOUNTADMIN` |

Constats faits en testant :

- **Qui est le donneur ?** Quand `ACCOUNTADMIN` exécute un `GRANT` sur un objet qu'un autre rôle possède, Snowflake enregistre le **propriétaire de l'objet** comme donneur (`granted_by`). Exemple : le `SELECT` des rôles métier sur `DIM_DRIVER` figure comme donné par `TRANSFORMER`. Pour retrouver qui a donné un droit, il faut donc lire `granted_by`, pas supposer le rôle qui a lancé le script.
- Les droits « futurs » n'apparaissent pas dans `SHOW GRANTS` : ils ont leur propre commande, `SHOW FUTURE GRANTS TO ROLE …`.

Constats sur le rôle `GOUVERNANCE` :

- Il a `USAGE` sur `RAW` et `MARTS` mais aucun `SELECT` : `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` renvoie `Object … does not exist or not authorized`, message identique à celui d'un objet qui n'existe pas.
- Dans l'exemple du bac à sable, le même rôle n'a pas vu la table avec `SHOW TABLES` et n'a pas pu lire les colonnes taguées dans `INFORMATION_SCHEMA`. Pour vérifier les tags des tables RH, utiliser `TRANSFORMER` : avec `GOUVERNANCE`, un résultat vide ne prouve rien.
- **Vérifié sur le bac à sable (exemples 02 et 03)** : `GOUVERNANCE` (rôle `EX_GOUVERNANCE`) a pu attacher une politique de masquage à un **tag** et une politique d'accès par ligne à une **table** qu'il ne voit pas, grâce aux droits `APPLY MASKING POLICY` et `APPLY ROW ACCESS POLICY` donnés sur le compte. Il lit `POLICY_REFERENCES` mais pas `TAG_REFERENCES_ALL_COLUMNS` : ce que le rôle peut vérifier dépend de la fonction. À revérifier sur les vraies tables au jour 2 (étapes 2.5 et 2.6).
- **Le filtre s'applique après le masque** : `WHERE email LIKE 'claire%'` renvoie 0 pour l'analyste (le filtre compare à la valeur masquée). Après une reconstruction de la table par `INSERT OVERWRITE`, les politiques restent en place.

### Ce que cette carte permet à un rôle de défaire

Pour chaque rôle qui peut poser ou retirer un tag, ou détacher une politique : que pourrait-il démasquer ? Est-ce acceptable, et qui le surveille ?

Première analyse (à valider, et à compléter au jour 2 quand les politiques existeront) :

- **`TRANSFORMER`** a `APPLY` sur les trois tags et possède les tables. Il peut donc retirer le tag `DONNEE_PERSONNELLE` d'une colonne : la politique de masquage n'ayant plus de tag à lire, la colonne serait vue en clair. Le rôle des outils fait tourner les tâches, donc son compte est un point sensible. À surveiller par la requête d'audit du jour 3 (qui a modifié ou retiré un tag, avec quel rôle).
- **`GOUVERNANCE`** peut détacher ou modifier une politique de masquage : il pourrait démasquer sans lire une seule donnée. C'est le rôle qui écrit les règles, donc ce pouvoir est voulu ; la surveillance repose sur l'historique des requêtes.
- **`ACCOUNTADMIN`** a donné ces droits et peut les reprendre. Il ne lit pas les données, mais peut s'attribuer un autre rôle. À encadrer par une revue des droits (`SHOW GRANTS`), pas par la technique seule.

---

## Partie 2 — Cahier de tests

Ce cahier est écrit **avant** les politiques de masquage et d'accès par ligne. La colonne « attendu » vient de la matrice du contrat (§4) et des décisions ci-dessous ; la colonne « obtenu » sera remplie après les politiques, en exécutant chaque requête avec le rôle indiqué (`USE SECONDARY ROLES NONE;`, `USE ROLE …;`, puis `USE WAREHOUSE NYC_TAXI_WH;`).

Un test est vert quand « obtenu » est identique à « attendu ». Un accès refusé (`Object does not exist or not authorized`) est un résultat comme un autre : il s'écrit tel quel. Les volumes viennent de `TRANSFORMER`, avant les politiques ; les valeurs de personnes ne sont jamais écrites dans ce fichier (il est public) : on note « en clair » ou « masqué ».

### Ce qu'est une valeur masquée

Une politique de masquage renvoie le **type qu'elle reçoit** : un texte masqué reste un texte, une date masquée reste une date.

| Type | Valeur masquée | Pourquoi |
|---|---|---|
| texte (nom, e-mail, téléphone, numéro de licence) | `*****` | un texte visiblement factice : personne ne le prend pour une vraie valeur ; il ne fait pas disparaître la ligne |
| date de naissance, pour `RESP_DEPOT_*`, `ACCOUNTADMIN`, `SYSADMIN`, `GOUVERNANCE` | `NULL` | une fausse date (1900-01-01) pourrait être prise pour une vraie |
| date de naissance, pour `ANALYSTE` | le **1er janvier de l'année de naissance** | le contrat autorise l'année seulement ; une date tronquée reste une date, donc `YEAR(birth_date)` fonctionne |

*Décision proposée, à valider.* Elle est écrite avant les politiques : si le résultat obtenu diffère, c'est la politique qu'on corrige, pas ce tableau.

### Décisions à trancher avant d'écrire les politiques

1. **Les politiques d'accès par ligne couvrent-elles aussi `RAW` ?** Le guide n'attache la politique qu'à `MARTS.DIM_DRIVER` et `MARTS.MART_DRIVER_MONTHLY`. Mais le contrat dit qu'un rôle absent de la matrice ne voit aucune ligne des « tables du domaine RH », et il nomme `RAW.DRIVERS` et `RAW.DRIVER_SHIFTS` parmi elles, et la matrice donne « aucune » ligne à `ACCOUNTADMIN`. Ces attendus supposent donc la politique **aussi sur `RAW`** : les tests 9 bis et 16 en dépendent. Sans elle, `ACCOUNTADMIN` verrait des lignes de `RAW` aux colonnes masquées.
2. **`ACCOUNTADMIN` et `SYSADMIN` héritent de `TRANSFORMER`** (installation) : ils peuvent donc *lire* les tables, mais n'étant pas dans `ACCES_DEPOT`, ils voient **0 ligne**. C'est l'attendu des tests 7 et 15.

### Volumes de référence (avant les politiques, rôle `TRANSFORMER`)

Calculés à partir du fichier en reproduisant les SQL fournis, puis confirmés dans Snowflake avec `TRANSFORMER` le 3 novembre 2026 (avant toute politique).

| Table | Total | Bronx | Brooklyn | Queens |
|---|---|---|---|---|
| `MARTS.DIM_DRIVER` | 400 | 122 | 117 | 161 |
| `MARTS.MART_DRIVER_MONTHLY` | 914 | 290 | 259 | 365 |
| `MARTS.DIM_DEPOT` | 3 | 1 | 1 | 1 |

Dans `RAW.DRIVERS`, le dépôt est mal écrit pour 9 chauffeurs : `BRONX ` (4, espace final) et `queens` (5, minuscules). `STAGING` les corrige, d'où 122 au Bronx (118 + 4) et 161 à Queens (156 + 5) dans `MARTS`. Dans `MART_DRIVER_MONTHLY`, 25 lignes ont un `driver_name` vide : ce sont des services de chauffeurs inconnus.

### Lignes visibles

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| 1 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 400 | | |
| 2 | `RESP_DEPOT_QUEENS` | la même | 161 | | |
| 3 | `RESP_DEPOT_QUEENS` | `SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER` | 1 ligne : `Queens` | | |
| 4 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | 290 | | |
| 5 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 400 | | |
| 6 | `GOUVERNANCE` | la même | refusé : `Object does not exist or not authorized` (`USAGE` sur `MARTS`, aucun `SELECT`) | | |
| 7 | `ACCOUNTADMIN` | la même | 0 (la requête réussit : le rôle lit la table par héritage, mais n'est pas dans `ACCES_DEPOT`) | | |
| 8 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS` | refusé : aucun droit sur `RAW` | | |
| 9 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` | refusé : aucun droit sur `RAW` | | |
| 9 bis | `ACCOUNTADMIN` | `SELECT first_name, email FROM NYC_TAXI.RAW.DRIVERS LIMIT 3` | 0 ligne (politique d'accès par ligne aussi sur `RAW`, voir décision 1) | | |

### Valeurs visibles

Pour le chauffeur `D0003` (dépôt de Queens, en poste), la valeur que chaque rôle doit lire dans chaque colonne (ou « ligne invisible »). « Clair » = la vraie valeur du fichier, non reproduite ici.

| Colonne | `RH_PAIE` | `RESP_DEPOT_QUEENS` | `RESP_DEPOT_BRONX` | `ANALYSTE` |
|---|---|---|---|---|
| `driver_id` | clair | clair | ligne invisible | clair |
| nom et prénom | clair | clair | ligne invisible | `*****` |
| e-mail | clair | `*****` | ligne invisible | `*****` |
| téléphone | clair | clair | ligne invisible | `*****` |
| date de naissance | date complète | `NULL` | ligne invisible | 1er janvier de l'année de naissance |
| numéro de licence | clair | `*****` | ligne invisible | `*****` |
| `driver_name` dans `MART_DRIVER_MONTHLY` | clair | clair | ligne invisible | `*****` |

### Le pipeline fonctionne toujours

| N° | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|
| 10 | Avec `TRANSFORMER`, après avoir relancé les fichiers SQL : nombre de lignes de `DIM_DRIVER` | 400 (la purge n'existe pas encore) ; `MART_DRIVER_MONTHLY` 914 | | |
| 11 | Avec `RH_PAIE` : l'e-mail de `D0003` est toujours une vraie adresse | contient un `@`, n'est pas `*****` | | |
| 12 | Les politiques sont toujours attachées après la relance : `POLICY_REFERENCES` sur `MARTS.DIM_DRIVER` (requête du contrat §7) | la politique d'accès par ligne sur `depot`, et la politique de masquage sur chacune des 7 colonnes taguées `DONNEE_PERSONNELLE` | | |

### Tests ajoutés (cas limites)

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| 13 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE email LIKE '%@%'` | 0 (l'e-mail est `*****`, aucun `@`) | | |
| 14 | `ANALYSTE` | `SELECT YEAR(birth_date) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003'` | une année, pas `NULL` | | |
| 15 | `SYSADMIN` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 0 (rôle absent de `ACCES_DEPOT`, qui hérite pourtant de `TRANSFORMER`) | | |
| 16 | `ACCOUNTADMIN` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS` | 0 (voir décision 1) | | |
| 17 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 122 : les 4 chauffeurs dont le dépôt est écrit `BRONX ` dans `RAW` sont visibles, car `STAGING` les corrige | | |
| 18 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003'` | 0 (chauffeur de Queens) | | |
| 19 | `GOUVERNANCE` | `SELECT * FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT` | 5 lignes : `RH_PAIE`, `ANALYSTE`, `TRANSFORMER`, `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX` (il lit la table de règles, qu'il possède, pas les données) | | |
| 20 | `RESP_DEPOT_QUEENS` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DEPOT` | 3 (référentiel lisible par tous les rôles métier, sans filtre de lignes) | | |
| 21 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.STAGING.STG_RH__DRIVERS` | refusé : aucun droit sur `STAGING` | | |
| 22 | `TRANSFORMER` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE email LIKE '%@%'` | un nombre > 0 : le rôle des outils lit les e-mails en clair | | |
| 23 | `TRANSFORMER` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_name = '*****'` | 0 (le pipeline n'a pas recopié de masque) | | |
| 24 | `RESP_DEPOT_QUEENS` | `SELECT driver_name FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_id = 'D0003' LIMIT 1` | clair (le contrat donne nom et prénom aux responsables de dépôt) | | |
| 25 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | 914 | | |

Ajoutez vos propres tests : un cahier qui ne contient que des tests verts dès le premier essai n'a probablement pas cherché les cas limites.
