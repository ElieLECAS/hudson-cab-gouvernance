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
| Lire `DIM_DRIVER` | rôles métier | `SELECT` sur la table, `USAGE` sur la base et sur `MARTS` (jour 2, `02_roles_metier.sql`) | `TRANSFORMER`, ou `ACCOUNTADMIN` selon le script |
| Exécuter une requête | chaque rôle | `USAGE` sur le warehouse `NYC_TAXI_WH`. Vérifié pour `TRANSFORMER` et `GOUVERNANCE`. | `ACCOUNTADMIN` |

Constats faits en testant (rôle `GOUVERNANCE`) :

- Il a `USAGE` sur `RAW` et `MARTS` mais aucun `SELECT` : `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` renvoie `Object … does not exist or not authorized`, message identique à celui d'un objet qui n'existe pas.
- Dans l'exemple du bac à sable, le même rôle n'a pas vu la table avec `SHOW TABLES` et n'a pas pu lire les colonnes taguées dans `INFORMATION_SCHEMA`. Pour vérifier les tags des tables RH, utiliser `TRANSFORMER` : avec `GOUVERNANCE`, un résultat vide ne prouve rien.

### Ce que cette carte permet à un rôle de défaire

Pour chaque rôle qui peut poser ou retirer un tag, ou détacher une politique : que pourrait-il démasquer ? Est-ce acceptable, et qui le surveille ?

Première analyse (à valider, et à compléter au jour 2 quand les politiques existeront) :

- **`TRANSFORMER`** a `APPLY` sur les trois tags et possède les tables. Il peut donc retirer le tag `DONNEE_PERSONNELLE` d'une colonne : la politique de masquage n'ayant plus de tag à lire, la colonne serait vue en clair. Le rôle des outils fait tourner les tâches, donc son compte est un point sensible. À surveiller par la requête d'audit du jour 3 (qui a modifié ou retiré un tag, avec quel rôle).
- **`GOUVERNANCE`** peut détacher ou modifier une politique de masquage : il pourrait démasquer sans lire une seule donnée. C'est le rôle qui écrit les règles, donc ce pouvoir est voulu ; la surveillance repose sur l'historique des requêtes.
- **`ACCOUNTADMIN`** a donné ces droits et peut les reprendre. Il ne lit pas les données, mais peut s'attribuer un autre rôle. À encadrer par une revue des droits (`SHOW GRANTS`), pas par la technique seule.

---

## Partie 2 — Cahier de tests

Décidez d'abord à quoi ressemble une valeur masquée pour chaque type de colonne (texte, date) et notez-le ici : ______. Puis remplissez en deux temps : la colonne « attendu » **avant** d'écrire les politiques, à partir de la matrice du contrat ; la colonne « obtenu » après, en exécutant la requête avec le rôle indiqué (`USE ROLE ...`).

Un test est vert quand « obtenu » est identique à « attendu ». Un accès refusé (`Object does not exist or not authorized`) est un résultat comme un autre : écrivez-le.

### Lignes visibles

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| 1 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | | | |
| 2 | `RESP_DEPOT_QUEENS` | la même | | | |
| 3 | `RESP_DEPOT_QUEENS` | `SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER` | | | |
| 4 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | | | |
| 5 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | | | |
| 6 | `GOUVERNANCE` | la même | | | |
| 7 | `ACCOUNTADMIN` | la même | | | |
| 8 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS` | | | |
| 9 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` | | | |
| 9 bis | `ACCOUNTADMIN` | `SELECT first_name, email FROM NYC_TAXI.RAW.DRIVERS LIMIT 3` | | | |

### Valeurs visibles

Pour le chauffeur `D0003`, la valeur que chaque rôle doit lire dans chaque colonne (ou « colonne absente », ou « ligne invisible »).

| Colonne | `RH_PAIE` | `RESP_DEPOT_QUEENS` | `RESP_DEPOT_BRONX` | `ANALYSTE` |
|---|---|---|---|---|
| nom et prénom | | | | |
| e-mail | | | | |
| téléphone | | | | |
| date de naissance | | | | |
| numéro de licence | | | | |
| `driver_name` dans `MART_DRIVER_MONTHLY` | | | | |

### Le pipeline fonctionne toujours

| N° | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|
| 10 | Avec le rôle des outils, après avoir relancé les fichiers SQL : nombre de lignes de `DIM_DRIVER` | | | |
| 11 | Avec `RH_PAIE` : l'e-mail de `D0003` est toujours une vraie adresse | | | |
| 12 | Les politiques sont toujours attachées après la relance (requête de la section 7 du contrat) | | | |

Ajoutez vos propres tests : un cahier qui ne contient que des tests verts dès le premier essai n'a probablement pas cherché les cas limites.
