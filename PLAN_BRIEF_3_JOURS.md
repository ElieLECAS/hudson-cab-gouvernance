# Plan de travail — Brief « Gouverner l'entrepôt NYC Taxi » (3 jours, en binôme)

> Plan d'action étape par étape, construit à partir du `GUIDE_BRIEF_GOUVERNANCE.md`, du `CONTRAT_GOUVERNANCE.md` et des critères d'évaluation (C4, C19, C20, C21).
> Le **pourquoi** de chaque étape est dans le cours : `COURS_GOUVERNANCE_SNOWFLAKE.md` (les § renvoient à ses sections).
> Chaque étape se termine par une **condition de fin vérifiable** : ne passez pas à la suite tant qu'elle n'est pas remplie.

---

## Vue d'ensemble

| Jour | Objectif | Livrables qui sortent | Compétences |
|---|---|---|---|
| Étape 0 | Un dépôt et un compte Snowflake prêts | dépôt cloné, kit copié, `NYC_TAXI` créé | C19 |
| J1 matin | Savoir quelles règles s'imposent | `docs/VEILLE.md`, `docs/REGISTRE.md` partie 1, écarts dans le README | C4, C20 |
| J1 après-midi | Charger sans publier, tout documenter | `.gitignore`, `01_gouvernance.sql`, fiches de catalogue, données dans RAW/MARTS | C19, C20 |
| J2 | Qui voit quoi : tests, puis politiques | `02_roles_metier.sql`, `03_masquage.sql`, `04_acces_depot.sql`, `docs/ACCES.md` vert | C21 |
| J3 | Conserver, contrôler, prouver, présenter | purge, conservation, qualité, `V_CATALOGUE`, tâches, audit, registre partie 2, README, démo | C19, C20, C21 |

### Organisation du binôme

- **Règle d'or : un test s'écrit avant la politique qu'il vérifie.** Pendant que A écrit une politique, B écrit le test qui la vérifiera ; puis on échange.
- Proposition de répartition (à alterner chaque demi-journée pour que chacun sache tout expliquer) :

| Bloc | Membre A | Membre B |
|---|---|---|
| J1 matin | droit applicable + dispositif de veille + 2 fiches | inventaire des données + 2 fiches + confrontation du contrat |
| J1 après-midi | `01_gouvernance.sql` + carte des droits | chargement + SQL fournis + fiches de catalogue |
| J2 | politiques (masquage puis filtrage) | cahier de tests (attendu) puis exécution (obtenu) |
| J3 | purge, conservation, tâches | qualité, vue catalogue, audit, registre |
| Démo | **partie 1 : la veille** (5 min) | **partie 2 : la gouvernance en direct** (10 min) |

- Chacun **relit** les fiches de veille de l'autre (exigé par le guide).
- Commit **fréquents et petits** à partir de l'étape 7 du J1 — jamais avant.

---

## Étape 0 — Préparer (≈ 30 min, avant le J1)

| # | Action | Condition de fin |
|---|---|---|
| 0.1 | Créer sur GitHub le dépôt **public** `hudson-cab-gouvernance`, **vide** (sans README ni `.gitignore`), le cloner | `git clone` OK |
| 0.2 | Copier le kit dedans avec la commande `sparse-checkout` du guide (étape 0.1.2) | à la racine : `CONTRAT_GOUVERNANCE.md`, `GUIDE_BRIEF_GOUVERNANCE.md`, `.gitignore`, `data/`, `docs/`, `exemples/`, `snowflake/` |
| 0.3 | ⚠️ **Ne faire ni `git add`, ni `commit`, ni `push`** avant l'étape 1.7 | — |
| 0.4 | Créer un compte d'essai Snowflake **édition Enterprise** ; choisir la région en conscience (vous en parlerez dans la veille) ; noter la région | connexion à Snowsight |
| 0.5 | Exécuter `snowflake/00_installation.sql` en entier avec `ACCOUNTADMIN` | `SHOW SCHEMAS` affiche `RAW`, `STAGING`, `MARTS` |
| 0.6 | Lire en entier : le guide, le contrat, la fiche juridique ; regarder les 2 vidéos « avant le premier jour » de `RESSOURCES.md` | chacun peut redire la question du brief |

**Les 4 réflexes à afficher sur un post-it** (cours §5.5, §4.4) :
1. `USE SECONDARY ROLES NONE;` avant chaque test de rôle.
2. `USE WAREHOUSE NYC_TAXI_WH;` après chaque `USE ROLE`.
3. Vérifier le rôle de la feuille Snowsight (en haut à droite) avant d'exécuter.
4. Finir chaque script par une requête de vérification.

---

## Jour 1 — Matin : la veille réglementaire (sans code)

**Lire d'abord** : `exemples/FICHE_JURIDIQUE.md` · cours §2 et §3 · sources `RESSOURCES.md` « Jour 1 — matin ».

**Préparer les documents** : copier les trois modèles (`VEILLE_MODELE.md` → `VEILLE.md`, `REGISTRE_MODELE.md` → `REGISTRE.md`, `ACCES_MODELE.md` → `ACCES.md`).

### 1.1 Lire le contrat et ouvrir les fichiers (30 min)
- Lire `CONTRAT_GOUVERNANCE.md` crayon en main : relever chaque **nom imposé**, chaque **règle** (R1, R2, R3, matrice, 8 règles de qualité).
- Ouvrir `data/drivers.csv` et `data/driver_shifts.csv` dans un éditeur ou un tableur. Repérer **à l'œil** les anomalies (dépôt mal écrit comme `BRONX ` avec espace, téléphones vides, e-mails douteux, dates bizarres, services en double…). Les noter : elles nourriront les règles de qualité au J3.
- ✅ Fin : une liste des objets imposés et une liste d'anomalies repérées.

### 1.2 Inventorier les données personnelles → `REGISTRE.md` partie 1 (45 min)
- Une ligne par colonne des **deux** fichiers : exemple de valeur, **direct / indirect / non**, valeur du tag `DONNEE_PERSONNELLE` (liste fermée du contrat §3 : `nom`, `email`, `telephone`, `date_naissance`, `identifiant_officiel`, `identifiant_interne`), **qui en a besoin et pour quoi**.
- Points de vigilance (cours §2.1–2.2) :
  - `driver_id` est une donnée personnelle (pseudonyme), tag `identifiant_interne`.
  - `tlc_license_number` : public à New York, mais identifiant **direct** → `identifiant_officiel`.
  - Les données d'activité (`hours_worked`, `revenue_usd`) rattachées à un `driver_id` décrivent une personne (indirect) même si aucune valeur du tag ne leur correspond : le signaler dans « Ce qui a surpris ».
- Commencer le tableau « Où cette donnée est-elle copiée ? » (RAW → STAGING → MARTS, y compris `driver_name` calculé dans `MART_DRIVER_MONTHLY`).
- ✅ Fin : les deux tableaux remplis, chaque colonne a un verdict.

### 1.3 Établir le droit applicable → `VEILLE.md` §1 (45 min)
- Appliquer la méthode de la fiche juridique à l'**article 3** : 3.1 oui/non parce que… ; 3.2 oui/non parce que… (cours §2.3).
- Nommer le **responsable du traitement** et le **sous-traitant** avec l'article 4 (et l'art. 28 pour le contrat de sous-traitance) (cours §2.4).
- Nommer l'**autorité de contrôle** compétente (art. 55–56).
- Vérifier la région de votre compte (`SELECT CURRENT_REGION();`) : si hors UE, ajouter la question du **transfert** (chapitre V).
- ✅ Fin : chaque réponse cite **le texte officiel et l'article** (pas la fiche juridique, pas un blog).

### 1.4 Mettre en place le dispositif de veille → `VEILLE.md` §2 (20 min)
- Au moins **3 sources officielles** (CNIL actualités/RSS, CEPD actualités, EUR-Lex ou Légifrance), une **fréquence**, un **outil** (Feedly, Inoreader, Thunderbird…).
- **S'abonner vraiment** au flux RSS de la CNIL (`https://www.cnil.fr/fr/rss.xml`) et au moins une autre source ; **capture** de l'abonnement dans `docs/`.
- Écrire **qui lit et qui décide** qu'une nouveauté demande une action.
- ✅ Fin : capture dans `docs/`, tableau rempli.

### 1.5 Rédiger au moins 4 fiches de veille → `VEILLE.md` §3 (45 min, 2 par personne)
- Une fiche = un texte. Suggestions : RGPD art. 3 ; RGPD art. 5 (minimisation + limitation de conservation) ; CEPD lignes directrices 3/2018 ; référentiel CNIL gestion du personnel (section 7, durées, base active vs archivage intermédiaire) ; CNIL durées de conservation ; CNIL sécurité ; transferts hors UE.
- Chaque fiche : source officielle + **date de publication + date de consultation**, ce que dit le texte (3 phrases, vos mots), **ce que ça change pour l'entrepôt** (tables, colonnes, rôles), action.
- ✅ Fin : 4 fiches minimum, **relues par l'autre membre**.

### 1.6 Confronter le contrat aux textes → `VEILLE.md` §4 et §5 + README (30 min)
- Une ligne par règle : R1, R2, R3, matrice des accès, règles de qualité (cours §3.3).
- Instruire au minimum ces pistes :
  - **R1** : d'où vient « 5 ans » ? Le contrat garde-t-il les partis en **base active** avec les mêmes accès ? (référentiel CNIL : archivage intermédiaire à accès restreint)
  - **R2** : Fail-safe de 7 jours non réductible sur les tables permanentes → délai réel ≠ 1 jour.
  - **Matrice** : chaque accès répond-il à un besoin (minimisation) ?
  - **Contrat antérieur au transfert** à Paris : région d'hébergement, transfert hors UE ?
- §5 « Ce que la veille ne tranche pas » : ex. une durée tirée du code du travail **français** pour des contrats **new-yorkais** ; d'éventuelles obligations new-yorkaises de conservation des données de paie. À qui poser la question (DPO, juriste).
- Créer le `README.md` avec une section **« Gouvernance »** et y recopier les **écarts** (signaler, pas réécrire).
- ✅ Fin : chaque règle a une ligne ; écarts dans le README ; **l'écart le plus important** identifié (il sera présenté à l'oral).

---

## Jour 1 — Après-midi : protéger le dépôt, charger, cataloguer

**Lire d'abord** : guide de cours `15-gouvernance.md` §5.3 (tags) · cours §5 à §8 · exécuter `exemples/00_bac_a_sable.sql` puis `exemples/01_role_gouvernance.sql` en **prévoyant** chaque résultat.

### 1.7 Ne pas publier le fichier du personnel (10 min)
- Décider : un fichier du personnel, même fictif, ne se publie pas (cours §16).
- Ajouter `data/` (ou les deux CSV) au `.gitignore`.
- Vérifier : `git status` ne montre plus les CSV ; `git check-ignore -v data/drivers.csv` confirme.
- Justifier en une phrase dans le README.
- **Premier commit + push** autorisé seulement maintenant.
- ✅ Fin : CSV absents de `git status` **et** du dépôt GitHub.

### 1.8 Charger les deux fichiers dans RAW (30 min)
- Avec `TRANSFORMER` : `snowflake/rh/chargement_rh_1_preparer.sql`.
- Dans Snowsight : Databases → NYC_TAXI → RAW → Stages → RH_STAGE → **+ Files** → déposer les 2 CSV. Vérifier `LIST @NYC_TAXI.RAW.RH_STAGE;` → 2 fichiers.
- Avec `TRANSFORMER` : `chargement_rh_2_copier.sql`. **Le relancer** : il ne doit rien charger de plus (cours §6.3, idempotence).
- Écrire dans le README quelques lignes sur : **format de fichier, stage, `COPY INTO`, `PURGE = TRUE` (R3)** — vous devrez l'expliquer à l'oral (critère C19).
- ✅ Fin : `RAW.DRIVERS` = **400**, `RAW.DRIVER_SHIFTS` = **25 951**, `LIST` du stage = **vide**.

### 1.9 Exécuter les SQL fournis (20 min)
- Avec `TRANSFORMER`, dans l'ordre : `rh/00_tables_rh.sql` → `staging/stg_rh__drivers.sql` → `staging/stg_rh__driver_shifts.sql` → `marts/dim_depot.sql` → `marts/dim_driver.sql` → `marts/mart_driver_monthly.sql`.
- ✅ Fin : `STG_RH__DRIVER_SHIFTS` = **25 933** · `DIM_DEPOT` = **3** · `DIM_DRIVER` = **400** · `MART_DRIVER_MONTHLY` = **914**.
- Si un script a été lancé par erreur avec `ACCOUNTADMIN` : réflexe 3 du guide (`GRANT OWNERSHIP … TO ROLE TRANSFORMER COPY CURRENT GRANTS`).

### 1.10 Écrire `snowflake/gouvernance/01_gouvernance.sql` (1 h)
Modèle : `exemples/00` et `exemples/01`. Script **rejouable** (`IF NOT EXISTS`, `SET TAG`, `GRANT` idempotents).

| Bloc | Rôle | Contenu |
|---|---|---|
| A | `ACCOUNTADMIN` | créer le rôle `GOUVERNANCE`, vous le donner ; `USAGE` sur base, warehouse, schémas `RAW` et `MARTS` (voir sans lire) ; créer le schéma `NYC_TAXI.GOUVERNANCE` et lui en **donner la propriété** ; `APPLY MASKING POLICY` et `APPLY ROW ACCESS POLICY` **on account** |
| B | `GOUVERNANCE` | créer les 3 tags avec `ALLOWED_VALUES` du contrat §3 (`DUREE_CONSERVATION` en texte libre) ; créer la table `QUALITE_RESULTATS` (`regle`, `mesure_le`, `nb_anomalies`, `seuil NUMBER(18,2)`, `statut`) |
| C | `GOUVERNANCE` → `TRANSFORMER` | `USAGE` sur le schéma ; `APPLY` sur **chacun** des 3 tags ; `INSERT, SELECT` sur `QUALITE_RESULTATS` ; `CREATE VIEW` sur le schéma |
| D | vérification | `SHOW TAGS IN SCHEMA NYC_TAXI.GOUVERNANCE;` (3 lignes) ; `SHOW GRANTS TO ROLE TRANSFORMER;` |

- Relancer le script une 2ᵉ fois : aucune erreur.
- Reporter **chaque droit** dans `ACCES.md` partie 1 (qui possède quoi, qui fait quoi avec quel droit).
- ✅ Fin : 3 tags, droits visibles, script rejoué sans erreur.

### 1.11 Écrire le catalogue (1 h 15)
- Exécuter le modèle `snowflake/gouvernance/modele_catalogue_dim_depot.sql` avec `TRANSFORMER`.
- Créer `snowflake/rh/catalogue/`, **un fichier par table** :

| Fichier | Fiche | Contenu |
|---|---|---|
| `catalogue_dim_driver.sql` | **complète** | description de la table (signification, source, rythme, responsable) + **chaque colonne** + `SENSIBILITE`, `DUREE_CONSERVATION` sur la table + `DONNEE_PERSONNELLE` sur chaque colonne personnelle |
| `catalogue_raw_drivers.sql` | **complète** | idem, y compris les colonnes techniques `_source_file`, `_loaded_at` |
| `catalogue_mart_driver_monthly.sql` | courte | description de la table + 2 tags de table + `DONNEE_PERSONNELLE` sur les colonnes personnelles (**dont `driver_name`, colonne calculée**, et `driver_id`) |
| `catalogue_raw_driver_shifts.sql` | courte | idem (`driver_id`) |

- Règles de rédaction (cours §8.2) : jamais « email : l'email » ; dire ce que signifie une valeur vide (`end_date` vide = en poste).
- Ne pas cataloguer les vues STAGING (elles héritent de la protection de RAW).
- Captures dans `docs/` : les tags d'une table dans Snowsight (Databases → table → Details).
- ✅ Fin : aucune colonne de `DIM_DEPOT`, `DIM_DRIVER`, `RAW.DRIVERS` sans `comment` dans `INFORMATION_SCHEMA.COLUMNS` ; description + tags sur les 4 tables RH.

### ✅ Bilan du J1 (à cocher avant de partir)
- [ ] `VEILLE.md` complet, relu croisé · [ ] `REGISTRE.md` partie 1 · [ ] écarts dans le README
- [ ] CSV hors de Git · [ ] 400 / 25 951 dans RAW, stage vide · [ ] volumes MARTS conformes
- [ ] `01_gouvernance.sql` rejouable · [ ] catalogue des 4 tables RH + `DIM_DEPOT`
- [ ] 2 captures : abonnement veille, tags d'une table
- [ ] Commit + push

---

## Jour 2 — Protéger : qui voit quoi

**Lire d'abord** : `15-gouvernance.md` §5.1 et §5.2 · cours §9 et §10 · exécuter `exemples/02_masquage_par_tag.sql` et `exemples/03_acces_par_ligne.sql` en **prévoyant** chaque résultat (et répondre aux questions finales). ⚠️ Ne pas utiliser l'atelier §11 du guide de cours (il crée les politiques avec `ACCOUNTADMIN`).

### 2.1 Exécuter les exemples 02 et 03 (45 min)
- Répondre par écrit : *que renvoie `WHERE email LIKE 'claire%'` pour l'analyste ?* ; *que se passerait-il avec `CREATE OR REPLACE TABLE … AS SELECT` ?*
- ✅ Fin : chaque membre sait expliquer le masquage par tag, l'exception par valeur de tag, la table de correspondance.

### 2.2 Créer les rôles métier → `snowflake/gouvernance/02_roles_metier.sql` (45 min)
Avec `ACCOUNTADMIN` :
- Créer `RH_PAIE`, `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX`, `ANALYSTE` (non rattachés entre eux) et **vous** les donner (pour tester).
- `USAGE` warehouse + base + schéma `MARTS` pour tous.
- `SELECT` sur `DIM_DRIVER`, `MART_DRIVER_MONTHLY`, `DIM_DEPOT` pour paie et responsables ; `SELECT` sur **toutes** les tables de `MARTS` **et les tables futures** pour l'analyste.
- `USAGE` sur le schéma `GOUVERNANCE` + `SELECT ON FUTURE VIEWS IN SCHEMA GOUVERNANCE` pour les 4 rôles (pour lire `V_CATALOGUE` au J3).
- Aucun droit sur `RAW` ni `STAGING`.
- Compléter `ACCES.md` partie 1.
- ✅ Fin : `SHOW GRANTS TO ROLE …` conforme à la matrice pour chaque rôle.

### 2.3 Écrire le cahier de tests AVANT les politiques → `ACCES.md` partie 2 (1 h)
- **Décider à quoi ressemble une valeur masquée**, par type : texte (`*****` ? `NULL` ? partiel ?), date (`NULL` ? 1ᵉʳ janvier de l'année ?). L'écrire.
- Remplir la colonne **« attendu »** de chaque test à partir de la matrice (contrat §4) : lignes visibles (tests 1 à 9 bis), valeurs pour `D0003` (chauffeur du dépôt **Queens** : donc ligne invisible pour `RESP_DEPOT_BRONX`), pipeline (tests 10 à 12).
- Pour les comptes attendus, calculer les volumes **avant** (avec `TRANSFORMER`) : nombre de chauffeurs par dépôt, nombre de lignes de `MART_DRIVER_MONTHLY` par dépôt.
- **Ajouter vos propres tests de cas limites**, par exemple :
  - `ANALYSTE` : `WHERE email LIKE '%@%'` → 0 ligne ? `YEAR(birth_date)` fonctionne-t-il ?
  - un rôle **absent** de la table de correspondance (ex. `SYSADMIN`) → 0 ligne ;
  - un chauffeur au dépôt mal saisi dans RAW (`BRONX `) : visible du responsable du Bronx dans MARTS ?
  - `GOUVERNANCE` sur `ACCES_DEPOT` (lit la table de règles, pas les données) ;
  - `ANALYSTE` lit `RAW.DRIVERS` → refusé.
- ✅ Fin : colonne « attendu » 100 % remplie, validée par les deux membres, **commitée** (preuve que le test précède la politique).

### 2.4 Décider, colonne par colonne : masquer ou supprimer (30 min)
Tableau de décision à mettre dans le README (cours §9.7). Grille de réflexion :

| Colonne (`DIM_DRIVER` / `MART_DRIVER_MONTHLY`) | Qui en a besoin en clair ? | Décision à prendre |
|---|---|---|
| `driver_id` | tous (compter, joindre) | visible de tous (exception si masquage par tag) |
| `first_name`, `last_name`, `driver_name` | paie, responsables de dépôt | masquer pour l'analyste |
| `email` | paie seulement | masquer pour responsables et analyste |
| `phone` | paie, responsables | masquer pour l'analyste |
| `birth_date` | paie ; analyste : **l'année** seulement | masquer (date tronquée à l'année pour l'analyste ?) |
| `tlc_license_number` | paie ? | masquer ou supprimer : à justifier |
| `hire_date`, `end_date`, `is_active`, `tenure_years` | à discuter | personnelles indirectes : faut-il les protéger ? |

- Si vous **supprimez** une colonne : la retirer des SQL fournis **et** `ALTER TABLE … DROP COLUMN` avec `TRANSFORMER` (cours §9.7).
- ✅ Fin : chaque colonne personnelle a une décision et une raison dans le README.

### 2.5 Écrire les politiques de masquage → `snowflake/gouvernance/03_masquage.sql` (1 h 15)
Avec `GOUVERNANCE`.
- Choisir : **par tag** (recommandé : le catalogue pilote la sécurité) ou par colonne.
- **Une politique par type** de colonne taguée (texte, date ; nombre si besoin).
- Dans le corps, dans cet ordre de priorité :
  1. exception `identifiant_interne` → en clair pour tous ;
  2. `TRANSFORMER` → en clair (sinon le pipeline recopie les masques, cours §7.3) ;
  3. `RH_PAIE` → en clair ;
  4. responsables → en clair seulement pour `nom` et `telephone` ;
  5. `ANALYSTE` → date de naissance réduite à l'année ;
  6. `ELSE` → masqué (deny by default : couvre `ACCOUNTADMIN`, `SYSADMIN`, `GOUVERNANCE`).
- Utiliser `CURRENT_ROLE()` (pas `IS_ROLE_IN_SESSION`) — savoir expliquer pourquoi (cours §9.4).
- Motif **rejouable** : `CREATE … IF NOT EXISTS` + `ALTER … SET BODY` + attache dans un bloc qui tolère « déjà attaché » (cours §9.6).
- Rappel : le tag est posé aussi sur les colonnes de **RAW** → l'admin y voit des valeurs masquées (contrat §4), et les vues STAGING aussi.
- ✅ Fin : `POLICY_REFERENCES` sur `DIM_DRIVER` montre les politiques ; script relancé 2 fois sans erreur.

### 2.6 Filtrer les lignes par dépôt → `snowflake/gouvernance/04_acces_depot.sql` (45 min)
Avec `GOUVERNANCE`.
- Créer `GOUVERNANCE.ACCES_DEPOT (role_name, depot)` ; choisir la notation « tous les dépôts » (`'*'` par exemple).
- Y écrire : `RH_PAIE` → tous ; `ANALYSTE` → tous ; `TRANSFORMER` → tous (**indispensable**) ; `RESP_DEPOT_QUEENS` → `Queens` ; `RESP_DEPOT_BRONX` → `Bronx`. Rien pour `GOUVERNANCE`, `ACCOUNTADMIN`.
- Écrire la politique (sous-requête `EXISTS` sur la table, `CURRENT_ROLE()`), corps provisoire + `SET BODY`.
- L'attacher à `MARTS.DIM_DRIVER` **et** `MARTS.MART_DRIVER_MONTHLY` sur la colonne `depot` (`DROP ALL ROW ACCESS POLICIES` puis `ADD` pour rejouer).
- Démontrer : ajouter une ligne (ex. un futur `RESP_DEPOT_BROOKLYN` ou Staten Island) **sans toucher la politique**.
- ✅ Fin : politique attachée aux 2 tables ; l'ajout d'un dépôt = un `INSERT`.

### 2.7 Dérouler le cahier de tests (1 h)
- Pour **chaque** rôle, y compris `ACCOUNTADMIN` et `GOUVERNANCE` : réflexes 1 et 2 à chaque changement de rôle.
- Remplir « obtenu », colorier vert/rouge. Un rouge → corriger la politique (pas le test), relancer.
- Expliquer par écrit le comportement de `ACCOUNTADMIN` (refusé ? 0 ligne ? valeurs masquées ? pourquoi ?).
- Capture dans `docs/` : **la même requête lue par deux rôles**.
- ✅ Fin : cahier **entièrement vert**.

### 2.8 Relancer les SQL fournis (15 min)
- Avec `TRANSFORMER` : relancer l'étape 1.9.
- Vérifier (tests 10 à 12) : mêmes volumes, `RH_PAIE` lit toujours une vraie adresse e-mail (pas `*****` recopié en dur), politiques toujours attachées (requête du contrat §7).
- ✅ Fin : tests 10–12 verts. Commit + push.

### ✅ Bilan du J2
- [ ] 4 rôles métier + carte des droits complète · [ ] décisions masquer/supprimer dans le README
- [ ] `03_masquage.sql` et `04_acces_depot.sql` rejouables · [ ] cahier de tests vert (attendu commité avant)
- [ ] pipeline relancé sans casse · [ ] capture « même requête, deux rôles »

---

## Jour 3 — Conserver, contrôler, auditer, présenter

**Lire d'abord** : `13-stockage-protection.md` §4–5 (Time Travel, Fail-safe) · `15-gouvernance.md` §6 (audit) · `18-transformation.md` §7 (tâches) · cours §11 à §14 · `exemples/04_vue_catalogue.sql` et `exemples/05_taches_planifiees.sql`.

### 3.1 Écrire la purge → `snowflake/rh/purge_rh.sql` (45 min)
- Avec `TRANSFORMER`. **D'abord compter** : combien de chauffeurs ont une `end_date` antérieure à « aujourd'hui − 5 ans » ? (Le résultat dépend de la date d'exécution : notez-la.)
- Purger la **source** `RAW.DRIVERS`.
- **Décider pour `RAW.DRIVER_SHIFTS`** : R1 dit « partout où la donnée a été copiée » ; et des services orphelins feraient monter `service_rattache` (bloquante, seuil 50). Justifier dans le README.
- Penser aux cas limites (`end_date` vide, incohérente) et à la question du guide : *un nouveau fichier complet depuis 2005 arrive le mois prochain — que devient votre purge ?* (réponse à écrire : la purge doit tourner **après chaque chargement**, d'où la tâche quotidienne).
- ✅ Fin : nombre purgé consigné ; `DIM_DRIVER` reconstruit en conséquence (après 3.6).

### 3.2 Time Travel puis R2 → `snowflake/rh/conservation_rh.sql` (30 min)
- **Avant** de fixer la rétention, prouver qu'une ligne purgée est encore lisible : `SELECT … AT(OFFSET => …)` ou `BEFORE(STATEMENT => '<query_id de la purge>')`. Capture/trace.
- Avec `TRANSFORMER` (propriétaire) : `DATA_RETENTION_TIME_IN_DAYS = 1` sur **chaque table contenant des données de chauffeurs** (RAW.DRIVERS, RAW.DRIVER_SHIFTS, DIM_DRIVER, MART_DRIVER_MONTHLY).
- Vérifier avec `SHOW PARAMETERS LIKE 'DATA_RETENTION%' IN TABLE …`.
- Noter dans le registre : **délai réel = 1 jour de Time Travel + 7 jours de Fail-safe = 8 jours** (et proposer l'alternative tables transitoires dans les limites/écarts).
- ✅ Fin : 4 tables à 1 jour, preuve Time Travel conservée.

### 3.3 Vérifier R3 (5 min)
- `LIST @NYC_TAXI.RAW.RH_STAGE;` → vide. Noter la preuve dans le registre.

### 3.4 Écrire les règles de qualité → `snowflake/rh/controles/` (45 min)
- Un fichier par règle, sur le modèle `licence_unique.sql` (1 ligne, 1 colonne `nb_anomalies`), mesurées **sur RAW**.
- Minimum : `licence_unique` (fournie) + `service_rattache` (**bloquante**, seuil 50) + au moins une autre. Bon choix complémentaire : `depot_connu` (révèle `BRONX `), `telephone_renseigne` (seuil en %, à convertir en nombre au moment de la mesure), `service_unique` (révèle les doublons : 25 951 → 25 933).
- Documenter chaque règle (énoncé, seuil, gravité) dans le README ou le registre (critère C20).
- ✅ Fin : chaque requête exécutée à la main donne un nombre ; résultats notés.

### 3.5 Créer `GOUVERNANCE.V_CATALOGUE` → `snowflake/rh/catalogue/` (45 min)
- Avec `TRANSFORMER` (qui a `CREATE VIEW` sur le schéma), à partir de `exemples/04`.
- Une ligne par colonne des 3 tables de **MARTS** : table, colonne, type, description, valeur de chaque tag (`DONNEE_PERSONNELLE`, `SENSIBILITE`, `DUREE_CONSERVATION`). Un bloc `TAG_REFERENCES_ALL_COLUMNS` par table, `UNION ALL`.
- Tester avec `ANALYSTE` (réflexes 1–2) : les 3 tables apparaissent, avec leurs tags.
- ✅ Fin : `ANALYSTE` lit la vue et retrouve une colonne personnelle avec description et tags (c'est un moment de la démo).

### 3.6 Automatiser → `snowflake/rh/taches_rh.sql` (1 h 15)
- Avec `TRANSFORMER`, à partir de `exemples/05`. Graphe imposé (contrat §1) :

| Tâche | Déclencheur | Contenu |
|---|---|---|
| `MARTS.T_PURGE` (racine) | `SCHEDULE` CRON quotidien | la purge de 3.1 (bloc `EXECUTE IMMEDIATE` si plusieurs `DELETE`) |
| `MARTS.T_QUALITE` | `AFTER T_PURGE` | pour chaque règle : mesurer → **insérer** dans `QUALITE_RESULTATS` (`OK`/`ALERTE`) ; **puis** `RAISE` si `service_rattache` dépasse 50 |
| `MARTS.T_TABLES` | `AFTER T_QUALITE` | les 3 `INSERT OVERWRITE` de `rh/marts/` **sans** `USE ROLE`/`USE WAREHOUSE`, dans un bloc |

- Activer : `SYSTEM$TASK_DEPENDENTS_ENABLE('NYC_TAXI.MARTS.T_PURGE')` ; lancer : `EXECUTE TASK` ; observer `TASK_HISTORY` filtré (`name IN (…) AND state <> 'SCHEDULED'`).
- **Prouver le blocage** : suspendre la racine, abaisser le seuil de `service_rattache`, réactiver, relancer → `T_QUALITE` `FAILED`, ligne `ALERTE` enregistrée, `T_TABLES` ne part pas. **Remettre le seuil**, relancer → tout `SUCCEEDED`.
- Captures : graphe des tâches avec une exécution réussie ; contenu de `QUALITE_RESULTATS`.
- ✅ Fin : 3 tâches `SUCCEEDED`, une ligne par règle et par exécution dans `QUALITE_RESULTATS`, blocage démontré.

### 3.7 Vérifier que les règles ont survécu (10 min)
- Après une exécution des tâches : requêtes du contrat §7 (`POLICY_REFERENCES`), `TAG_REFERENCES_ALL_COLUMNS`, `comment` dans `INFORMATION_SCHEMA.COLUMNS`, et un test du cahier (ex. `ANALYSTE` sur `D0003`).
- ✅ Fin : politiques, tags, descriptions intacts (critère C19).

### 3.8 Auditer → `snowflake/gouvernance/06_audit.sql` (45 min)
- Avec `ACCOUNTADMIN` : `ACCESS_HISTORY` + `LATERAL FLATTEN(base_objects_accessed)` filtré sur `NYC_TAXI.MARTS.DIM_DRIVER`, 7 derniers jours ; **jointure `QUERY_HISTORY` sur `query_id`** pour obtenir `role_name` ; agréger par rôle et utilisateur (et colonnes lues, en bonus).
- ⚠️ Latence jusqu'à 3 h : vos tests du J2 doivent y apparaître ; ceux de la dernière heure, pas forcément.
- Capture du résultat.
- ✅ Fin : la requête nomme les rôles qui ont lu `DIM_DRIVER`.

### 3.9 Lignage (5 min)
- Snowsight → `MART_DRIVER_MONTHLY` → onglet **Lineage** → capture (peut mettre quelques minutes à se mettre à jour).

### 3.10 Finaliser les documents (1 h)
- `REGISTRE.md` partie 2 : chaque réponse **avec sa preuve** (fichier ou requête). Délai réel de disparition (8 jours). « Que se passe-t-il si le rôle des outils est compromis ? » (il voit tout en clair et possède les tables → limite à écrire).
- `README.md`, section « Gouvernance » :
  1. ce qui est protégé et comment (tableau rôle × colonne × lignes) ;
  2. **ordre d'exécution** de tous les scripts (installation → chargement → SQL fournis → `01` → catalogue → `02` → `03` → `04` → purge → conservation → contrôles → vue catalogue → tâches → audit) avec le rôle de chaque script ;
  3. choix techniques (masquage par tag, `CURRENT_ROLE`, `'*'`, masquer vs supprimer, purge des services…) ;
  4. écarts contrat/textes (J1) ;
  5. **limites connues** (ex. `ACCOUNTADMIN` peut s'octroyer `GOUVERNANCE` ; le rôle des outils voit tout ; Fail-safe ; base active vs archivage non distingués ; latence de l'audit).
- Vérifier : aucune donnée personnelle ni secret dans le dépôt (captures comprises).
- **Suspendre la racine des tâches** à la fin (`ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;`) — après la démo si elle doit tourner en direct.
- ✅ Fin : quelqu'un d'extérieur peut rejouer toute l'installation **uniquement avec le README**.

### 3.11 Préparer la démonstration (45 min, répétée une fois chronomètre en main)

**Partie 1 — La veille (≈ 5 min, membre A)**
1. Le droit applicable : RGPD oui, **par quel article** (3.1), responsable / sous-traitant, autorité de contrôle.
2. L'écart le plus important entre le contrat et les textes, et la proposition du binôme.
3. Le dispositif : sources, fréquence, outil (montrer l'abonnement), qui décide.

**Partie 2 — La gouvernance (≈ 10 min, membre B, en direct dans Snowsight)**
1. *À quoi ça sert* (1 min) : qui voit quoi, combien de temps, peut-on s'y fier.
2. *Catalogue* : interroger `V_CATALOGUE`, retrouver `email` avec description et tags.
3. *Masquage + filtrage* : **la même requête avec 4 rôles** (feuilles préparées à l'avance, une par rôle, réflexes inclus).
4. *Table de correspondance* : `INSERT` d'un nouveau dépôt, la politique ne bouge pas.
5. *Tâches* : `EXECUTE TASK`, `TASK_HISTORY`, `QUALITE_RESULTATS`, puis `POLICY_REFERENCES` (les règles sont toujours là).
6. *Conservation + audit* : avant/après purge, Time Travel, rétention à 1 jour, requête d'audit.

Préparez des **feuilles Snowsight nommées par moment de la démo** et un plan B en captures si une latence (audit, lignage) vous trahit.

### ✅ Bilan du J3
- [ ] purge + rétention + R3 prouvées · [ ] ≥ 3 règles de qualité dont `service_rattache`
- [ ] `V_CATALOGUE` lisible par `ANALYSTE` · [ ] 3 tâches `SUCCEEDED` + blocage démontré
- [ ] règles intactes après tâches · [ ] requête d'audit avec rôles
- [ ] 4 captures : Lineage, graphe des tâches, `QUALITE_RESULTATS`, audit
- [ ] `REGISTRE.md` partie 2 · [ ] README complet · [ ] tâches suspendues · [ ] démo répétée

---

## Bonus (si le temps le permet)

| Bonus | Où | Idée de livrable |
|---|---|---|
| 1. Classification | `snowflake/gouvernance/bonus_classification.sql` | `SYSTEM$CLASSIFY` sur `RAW.DRIVERS`, tableau comparatif avec l'inventaire du J1 dans `REGISTRE.md` |
| 2. Alerte | `snowflake/rh/bonus_alerte.sql` | `CREATE ALERT` qui envoie un e-mail si une ligne `ALERTE` apparaît dans `QUALITE_RESULTATS` |
| 3. Agrégation | `snowflake/gouvernance/bonus_agregation.sql` | politique d'agrégation pour `ANALYSTE` (groupes d'au moins N lignes) |

---

## Arborescence finale attendue du dépôt

```
hudson-cab-gouvernance/
├── README.md                         ← section « Gouvernance » (protégé/comment, ordre, choix, écarts, limites)
├── CONTRAT_GOUVERNANCE.md            ← fourni, non modifié
├── GUIDE_BRIEF_GOUVERNANCE.md        ← fourni
├── .gitignore                        ← + data/
├── data/                             ← IGNORÉ par Git
├── docs/
│   ├── VEILLE.md
│   ├── REGISTRE.md
│   ├── ACCES.md
│   └── captures (abonnement, tags, 2 rôles, lineage, graphe tâches, qualité, audit)
├── exemples/                         ← fourni
└── snowflake/
    ├── 00_installation.sql
    ├── gouvernance/
    │   ├── modele_catalogue_dim_depot.sql
    │   ├── 01_gouvernance.sql        ← rôle GOUVERNANCE, schéma, tags, QUALITE_RESULTATS, droits
    │   ├── 02_roles_metier.sql
    │   ├── 03_masquage.sql
    │   ├── 04_acces_depot.sql        ← ACCES_DEPOT + politique d'accès par ligne
    │   └── 06_audit.sql
    └── rh/
        ├── 00_tables_rh.sql, chargement_rh_1_preparer.sql, chargement_rh_2_copier.sql
        ├── staging/ , marts/         ← SQL de Priya (modifiés si colonnes supprimées)
        ├── catalogue/                ← 1 fiche par table + vue V_CATALOGUE
        ├── controles/                ← 1 fichier par règle de qualité
        ├── purge_rh.sql
        ├── conservation_rh.sql
        └── taches_rh.sql
```

---

## Checklist finale par critère d'évaluation

### C4 — Veille technique et réglementaire
- [ ] Droit applicable établi et justifié **par l'article précis** (art. 3.1 + art. 4.7 / 4.8)
- [ ] ≥ 3 sources officielles, une fréquence, un outil **en place** (capture)
- [ ] ≥ 4 fiches avec source, date, et impact sur l'entrepôt
- [ ] Chaque règle du contrat confrontée ; écarts **dans le README**

### C19 — Intégrer les composants d'infrastructure
- [ ] Chargement expliqué (format, stage, `COPY INTO`, `PURGE`) ; stage vide
- [ ] `T_PURGE → T_QUALITE → T_TABLES` réussissent avec `TRANSFORMER`
- [ ] Politiques, tags, descriptions intacts après les tâches
- [ ] README = installation rejouable dans l'ordre ; aucun secret ni donnée perso

### C20 — Gérer le catalogue
- [ ] Description de chaque table RH (signification, source, rythme) ; chaque colonne de `DIM_DRIVER` et `RAW.DRIVERS`
- [ ] `DONNEE_PERSONNELLE` sur **toutes** les colonnes personnelles, **colonnes calculées comprises** ; `SENSIBILITE` + `DUREE_CONSERVATION` sur chaque table
- [ ] `V_CATALOGUE` lisible par un rôle métier
- [ ] Règles de qualité documentées (énoncé, seuil, gravité) ; lignage présenté

### C21 — Implémenter les règles de gouvernance
- [ ] Cahier de tests vert pour chaque rôle, **`ACCOUNTADMIN` et `GOUVERNANCE` compris**
- [ ] Ajouter un dépôt = une ligne dans `ACCES_DEPOT`
- [ ] Purge > 5 ans dans **toutes** les tables ; Time Travel = 1 jour
- [ ] ≥ 3 règles de qualité dont `service_rattache` ; la bloquante arrête la chaîne
- [ ] Requête d'audit (qui a lu, avec quel rôle) ; registre renseigné avec preuves

---

## Les 10 pièges qui coûtent le plus de temps

1. Commiter avant d'avoir ignoré `data/` → fuite **définitive** dans l'historique.
2. Oublier `USE SECONDARY ROLES NONE` → tests faussement rouges/verts.
3. Exécuter un SQL fourni avec `ACCOUNTADMIN` → objets que `TRANSFORMER` ne peut plus modifier.
4. Oublier `TRANSFORMER` dans les exceptions de masquage → `*****` écrit en dur dans MARTS.
5. Oublier `TRANSFORMER` dans `ACCES_DEPOT` → `driver_name` vide partout, sans erreur.
6. `CREATE OR REPLACE TABLE` quelque part → tags, descriptions, politiques perdus.
7. Script de politiques non rejouable → échec au 2ᵉ passage.
8. Oublier l'exception `driver_id` dans un masquage par tag.
9. Purger les chauffeurs sans leurs services → `service_rattache` bloque la chaîne.
10. Laisser les tâches actives après le brief → crédits consommés chaque jour.
