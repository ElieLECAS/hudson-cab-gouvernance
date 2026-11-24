# Bilan du brief « Gouverner l'entrepôt NYC Taxi »

Ce document fait le point, après trois jours de travail, sur ce que le brief attendait, ce que nous avons fait et vu, ce que nous avons appris, et sur les écarts. Il se lit en trois temps : un tableau (1), un examen honnête des écarts (2), puis le récit complet en prose (3).

Quelques repères pour lire la suite :

- Le brief est écrit pour un binôme ; il a été fait **seul**, avec Claude. Claude a écrit les documents et les scripts à la demande de l'apprenant, qui exécutait dans Snowsight et validait.
- Les trois jours se sont tenus du 2 au 4 novembre 2026. Mesuré sur les horaires des commits : le jour 1 après-midi a pris environ 4 h 15 pour 3 h 15 prévues ; le jour 2, environ 2 h 40 pour 6 h 15 prévues ; le jour 3, environ 2 h pour 6 h 50 prévues. Le gain vient surtout du fait que les scripts et les tests étaient écrits à l'avance et envoyés dans le presse-papiers.
- Le dépôt compte neuf commits, un cahier de tests de 25 tests tous verts, huit règles de qualité, trois tâches planifiées, treize captures, et quatre documents (`VEILLE.md`, `REGISTRE.md`, `ACCES.md`, `README.md`).

---

## 1. Ce qui était attendu, ce que nous avons vu, ce que nous avons appris

| Étape du brief | Ce qui était attendu | Ce que nous avons fait et vu | Ce que nous avons appris |
|---|---|---|---|
| **Veille** (C4) | Droit applicable établi par article ; au moins trois sources officielles, une fréquence, un outil en place ; au moins quatre fiches ; contrat confronté aux textes | RGPD art. 3 §1 : Hudson Cab Europe est responsable du traitement ; Snowflake sous-traitant ; CNIL compétente. Cinq sources, abonnement Feedly au flux de la CNIL (deux captures), six fiches, sept écarts contrat/textes, huit questions ouvertes | Le règlement s'applique parce que le responsable est établi à Paris, **pas** parce que les chauffeurs vivent à Paris. La région du compte compte aussi : elle est à Londres, donc un transfert couvert par une décision d'adéquation (valable jusqu'au 27 décembre 2031) |
| **Inventaire** (registre, partie 1) | Un verdict par colonne des deux fichiers ; où chaque donnée est copiée | 18 colonnes jugées (directes, indirectes, neutres), tableau des copies de RAW à MARTS | Une colonne calculée à partir d'une donnée personnelle (`driver_name`) est une donnée personnelle ; des mesures d'activité deviennent personnelles dès qu'elles portent un `driver_id` |
| **Chargement** (C19) | Fichiers dans RAW, stage vide, expliqué | 400 chauffeurs et 25 951 services ; `PURGE = TRUE` retire les fichiers du stage ; tailles et sommes de contrôle identiques à celles du poste | Un stage vide fait échouer un second `COPY INTO` (clause `FILES`) : relancer n'est pas anodin |
| **SQL fournis** | 25 933 · 3 · 400 · 914 | Valeurs exactes | L'écart de 18 services vient d'une seule cause : les doublons d'identifiant, dédoublonnés en staging. `INSERT OVERWRITE` plutôt que `CREATE OR REPLACE` préserve ce qui est posé sur les tables |
| **Gouvernance de base** | Rôle `GOUVERNANCE` qui n'a pas à lire, schéma, 3 tags, table de résultats, droits | `01_gouvernance.sql` rejouable, 7 droits donnés à `TRANSFORMER`, `GOUVERNANCE` refusé sur `RAW` | `USAGE` n'est pas `SELECT` ; un rôle sans droit reçoit le même message qu'un objet inexistant ; Snowflake note comme donneur le **propriétaire** de l'objet |
| **Catalogue** (C20) | Descriptions des tables et colonnes de `DIM_DRIVER` et `RAW.DRIVERS`, tags, `V_CATALOGUE` lisible par un rôle métier | Cinq tables décrites (24 colonnes de MARTS), 9 colonnes personnelles taguées, vue lue à l'identique par `ANALYSTE` | Un tag posé sur une table est hérité par ses colonnes ; une vue s'évalue avec les droits de son propriétaire, ce qui règle le piège d'`INFORMATION_SCHEMA` |
| **Rôles métier** | Quatre rôles, droits de la matrice, rien sur RAW ni STAGING | `02_roles_metier.sql`, contrôle : 7 droits chacun, 0 sur RAW et STAGING | `SHOW GRANTS` ne liste pas les droits « futurs » ; l'analyste a besoin d'un droit sur les tables futures |
| **Cahier de tests « attendu »** | Écrit **avant** les politiques et commité | 25 tests écrits, volumes calculés, commités (`00501f3`) avant la première politique (`8526230`) | Un test se rédige à partir du contrat, pas du comportement obtenu : c'est ce qui le rend honnête |
| **Masquage** | Politique par type, exception `driver_id`, `TRANSFORMER` en clair, `CURRENT_ROLE()` | `MASK_TEXTE` et `MASK_DATE` attachées au tag ; date masquée = `NULL`, sauf `ANALYSTE` (1er janvier) | Le filtre s'applique après le masque (`LIKE 'claire%'` renvoie 0) ; `GOUVERNANCE` attache une politique à un tag sans voir les tables |
| **Accès par dépôt** | Table de correspondance, politique attachée aux tables, ajout d'un dépôt sans toucher la politique | `ACCES_DEPOT`, `RAP_DEPOT` sur quatre tables (aussi `RAW`) ; démontré sur le bac à sable | Un administrateur lit les tables par héritage mais voit **0 ligne** : la politique regarde le rôle actif, pas sa puissance |
| **Tests exécutés** | Cahier entièrement vert, y compris `ACCOUNTADMIN` et `GOUVERNANCE` | 8 rôles, 25 tests, 28 valeurs, tous verts ; capture de la même requête lue par deux rôles | Un script par rôle qui renvoie une table donne une preuve lisible sans afficher de donnée |
| **Pipeline relancé** | Mêmes volumes, vraie adresse e-mail pour `RH_PAIE`, politiques toujours attachées | Test 10, 11, 12 verts, puis refaits après les tâches | Si le rôle des outils ne figurait pas dans `ACCES_DEPOT`, le mart se reconstruirait vide sans erreur |
| **Purge et conservation** (R1, R2, R3) | Purge à 5 ans dans toutes les tables, Time Travel prouvé puis rétention 1 jour, stage vide | 46 chauffeurs purgés (400 → 354), 0 service concerné, Time Travel : 400 lignes relues juste avant, rétention 1 jour sur 4 tables, stage à 0 | La rétention valait déjà 1 jour : on la rend explicite. Délai réel de disparition : **8 jours** (Time Travel + 7 de Fail-safe, non réductible) |
| **Qualité** | Au moins trois règles dont `service_rattache` bloquante | Huit règles ; 6 en `ALERTE`, 2 `OK` ; blocage prouvé avec un seuil abaissé à 10 | Enregistrer le résultat **avant** de lever l'erreur laisse la trace de ce qui a bloqué |
| **Tâches** (C19) | `T_PURGE → T_QUALITE → T_TABLES`, quotidiennes, `SUCCEEDED` avec `TRANSFORMER` | Trois tâches réussies, graphe capturé, puis suspendues | Une tâche tourne avec les droits de son propriétaire ; une sous-requête dans `SELECT … INTO` est refusée ; `COMMENT` précède `AFTER` |
| **Règles survivantes** | Politiques, tags, descriptions intacts après les tâches | 10 contrôles du rôle des outils, 8 références de politiques, masquage vu par l'analyste : identiques | `INSERT OVERWRITE` ne retire ni tag, ni description, ni politique |
| **Audit** | Qui a lu `DIM_DRIVER` | 8 lignes ; les tâches apparaissent sous l'utilisateur `SYSTEM` ; `GOUVERNANCE` est absent | Le rôle vient de `QUERY_HISTORY` ; seules les requêtes réussies sont tracées, avec un retard |
| **Lignage** | Capture du lineage de `MART_DRIVER_MONTHLY` | `DIM_DRIVER` et `STG_RH__DRIVER_SHIFTS` → mart | Il demande un warehouse ; il montre un niveau à la fois |
| **Registre, README** | Registre partie 2 avec preuves, ordre d'exécution, limites | Registre complet, README de près de 200 lignes, 16 étapes d'exécution, limites détaillées | Écrire les limites oblige à relire les décisions prises en route (masquer, dates en clair, `driver_name`) et à dire ce qu'elles coûtent |
| **Démonstration** | Veille (5 min) puis gouvernance en direct (10 min) | **Non concernée** : une autre personne est désignée | Le dépôt est conçu pour qu'on puisse présenter à partir des captures et des scripts de test |
| **Bonus** | Classification, alerte, politique d'agrégation | **Non faits** | |

---

## 2. Avons-nous digressé ?

**En grande partie, non.** Le travail a suivi l'ordre du plan, jour par jour, et chaque livrable demandé existe. La règle d'or du brief a été tenue : le cahier de tests « attendu » a été commité avant la première politique.

### Ce que nous avons ajouté, et qui reste utile

| Ajout | Pourquoi je le juge utile, pas parasite |
|---|---|
| **Huit règles de qualité** au lieu de trois | Le contrat les demande toutes ; trois est un minimum. Elles servent d'exemples pour la mise en garde sur la qualité |
| **Politique par ligne aussi sur `RAW`** | Le guide ne cite que `MARTS`, mais le contrat range `RAW` dans les tables du domaine RH et donne « aucune ligne » à `ACCOUNTADMIN` |
| **Douze scripts de test** : huit par rôle, les autres pour la relance, les politiques, les tâches et le catalogue | Le brief demande un cahier de tests ; ces scripts le rendent exécutable en une fois par rôle |
| **Analyse de la région Londres** | Le brief invite à regarder `CURRENT_REGION()` ; le résultat (pays tiers) a ouvert une vraie question juridique |
| **Vérifications sur sources officielles** (Légifrance, documentation Snowflake) | Deux affirmations du registre reposaient sur des sources que j'avais signalées comme non vérifiées |
| **`suspendre_taches.sql`**, `preuves_purge.sql`, `demo_blocage_tache.sql` | Fichiers de support des preuves demandées |

### Ce qui s'écarte du brief ou de la méthode annoncée

- **Un binôme attendu, un apprenant seul.** La relecture croisée n'a pas eu lieu. Le brief la prévoit pour la veille et les tests.
- **Claude a écrit les livrables.** Le projet avait au départ pour règle d'expliquer et de relire plutôt que d'écrire. Elle a été levée à la demande de l'apprenant (« Je veux pas écrire moi-même », puis « simule mes choix »). C'est un écart de méthode, avec un risque réel : l'apprenant doit pouvoir expliquer chaque ligne à l'oral. Il lui reste à relire `VEILLE.md`, `REGISTRE.md` et le README.
- **Des décisions à la place de l'apprenant.** Au jour 3, j'ai tranché la purge, le sort des services, les seuils et le sort des orphelins. Elles sont écrites dans le README et peuvent être refusées.
- **La démonstration a été retirée.** Une autre personne présente ; l'étape 3.11 n'a pas été faite.
- **Les prédictions demandées à l'apprenant** ont été appliquées au jour 1 et pour les exemples du jour 2. Elles ne sont pas exigées par le brief pour les exemples 00 et 01.
- **Une capture adaptée** : « la même requête lue par deux rôles » est montrée sous forme de tableaux « clair » / « masqué », pas avec les vraies valeurs, parce que le dépôt est public.

### Ce qui n'a pas été fait

Les bonus (classification, alerte, politique d'agrégation) ; la relecture croisée ; la préparation de la démonstration ; la vérification de quelques points juridiques signalés dans `VEILLE.md` (articles 26 et 37 du RGPD, version consolidée, date de publication au JOUE de la décision sur le Royaume-Uni, accès depuis les États-Unis).

### Où nous nous sommes trompés

La liste complète, parce qu'elle fait partie de ce qu'on a appris :

| Erreur | Cause | Correction |
|---|---|---|
| L'installation s'arrête au `GRANT … TO USER` | un nom d'utilisateur avec un point exige des guillemets doubles | corrigé dans `00_installation.sql`, `exemples/00` et `01_gouvernance.sql` |
| J'ai dit qu'un second `COPY INTO` avec un stage vide ne chargerait « rien » | il échoue sur la clause `FILES` | noté dans le README ; le cas d'un fichier redéposé n'est pas testé |
| Le commentaire de l'exemple 00 disait que `GOUVERNANCE` voit les tables | `SHOW TABLES` était vide pour ce rôle | constat noté, kit non modifié |
| Test 12 lancé avec `TRANSFORMER` : `NULL` | cause non établie | refait avec `GOUVERNANCE`, noté dans les limites du cahier |
| `T_QUALITE` échoue au premier lancement | sous-requête dans un `SELECT … INTO` | seuil réécrit sans sous-requête ; une ligne partielle de `QUALITE_RESULTATS` supprimée |
| `CREATE TASK` refuse la syntaxe | `COMMENT` doit précéder `AFTER` | ordre corrigé |
| J'ai enchaîné la 3.4 sans résultat de 3.1 à 3.3 | « on continue » compris comme « c'est fait » | retour en arrière, presse-papiers refait |

---

## 3. Le récit complet, en prose

### Le point de départ

Le brief place le travail dans une entreprise fictive, Hudson Cab Partners, flotte de taxis jaunes new-yorkaise répartie sur trois dépôts, le Bronx, Brooklyn et Queens. Un entrepôt Snowflake contient désormais le fichier du personnel (des noms, des e-mails, des téléphones, des dates de naissance, des numéros de licence) et le relevé des services de janvier à mars 2025. Une analyste, Priya, a construit les tables sans se demander qui devait voir quoi. Depuis cette année, la gestion de ces données est confiée à une entité parisienne, Hudson Cab Europe, et le contrat de gouvernance a été écrit avant ce transfert. La question de toute la mission tient en une phrase : qui peut voir quelle donnée, pendant combien de temps, et peut-on s'y fier ?

Nous avons d'abord posé le cadre : un cours de dix sections sur Snowflake et la gouvernance, un plan en trois jours, et un fichier de règles de travail. Le fichier de règles disait que l'apprenant devait pouvoir expliquer chaque ligne, que les exemples du kit se lisent et s'adaptent, que chaque affirmation juridique cite un texte officiel, et que les secrets et les données personnelles ne doivent jamais entrer dans le dépôt public. Nous avons ajouté un `.gitignore` avant le premier commit : le dossier `data/`, les listes de tâches personnelles et les clés.

### Le matin du premier jour : savoir ce que dit le droit

Nous avons commencé sans écrire une ligne de SQL. Le RGPD s'applique-t-il à des chauffeurs new-yorkais ? Nous avons lu l'article 3 sur EUR-Lex et les lignes directrices 3/2018 du comité européen de la protection des données. La réponse est oui, et le lieu où vivent les chauffeurs n'y change rien : c'est l'établissement du responsable du traitement, à Paris, qui rend le règlement applicable (article 3, paragraphe 1). Snowflake, qui héberge pour le compte de l'entité, est sous-traitant ; l'autorité compétente est la CNIL.

Nous avons ensuite confronté le contrat aux textes, point par point. Trois règles de conservation, une matrice d'accès, huit règles de qualité. La durée de cinq ans après la fin du contrat ressemble à ce que la CNIL cite pour le registre du personnel, mais elle vient d'un code du travail français, et rien ne distingue la base active de l'archivage. Le délai de restauration limité à un jour oublie les sept jours de Fail-safe de Snowflake : une donnée supprimée n'a réellement disparu qu'au bout de huit jours. En comptant dans le fichier, 46 chauffeurs étaient partis depuis plus de cinq ans : leurs données auraient déjà dû être supprimées. Le contrat ne dit rien non plus de la région du compte, du contrat de sous-traitance ni de l'information des chauffeurs.

Pour le dispositif de veille, nous avons retenu cinq sources, dont le flux de la CNIL, auquel l'apprenant s'est abonné dans Feedly : deux captures le prouvent. Six fiches de veille résument les textes qui comptent, chacune avec sa source, sa date et son impact. Nous avons aussi dressé l'inventaire de chaque colonne des deux fichiers : direct, indirect ou neutre, avec le tag prévu, et la liste des endroits où chaque donnée se retrouve, du stage jusqu'au mart. Deux surprises : le nom d'un chauffeur se retrouve dans une table de chiffres (`driver_name`, colonne calculée), et des colonnes d'apparence neutre, comme les heures ou la recette, deviennent personnelles dès qu'elles portent l'identifiant d'un chauffeur.

### L'après-midi du premier jour : charger, poser le socle, décrire

Le compte Snowflake, édition Enterprise, a été créé. Une première erreur est tombée tout de suite : le script d'installation s'arrêtait sur l'attribution du rôle à l'utilisateur, parce que le nom d'utilisateur contenait un point. Il a fallu l'entourer de guillemets doubles, dans ce script et dans trois autres. La région du compte est apparue à ce moment : Londres. Le Royaume-Uni n'est plus dans l'Union, donc l'hébergement est un transfert vers un pays tiers ; il est couvert par une décision d'adéquation de la Commission, renouvelée en décembre 2025 et valable jusqu'au 27 décembre 2031, que nous avons relue dans le texte officiel.

Le chargement s'est fait en trois temps : un format de fichier et un stage, le dépôt des deux CSV depuis Snowsight, puis un `COPY INTO` avec `PURGE = TRUE` qui retire chaque fichier du stage une fois copié. Le résultat était exact : 400 chauffeurs et 25 951 services, stage vide. Les six scripts du kit ont ensuite construit les vues de nettoyage et les tables de `MARTS`, avec les volumes attendus (25 933, 3, 400, 914). Nous avons compris d'où venait l'écart de dix-huit services : les doublons d'identifiant, que la vue de staging dédoublonne.

Avant d'écrire le premier script de gouvernance, nous avons joué avec un bac à sable : une petite base d'entraînement, quatre rôles, six clients fictifs. Deux constats, notés ensuite : avoir le droit d'entrer dans un schéma ne donne aucun droit de lire ses tables, et un rôle qui n'a aucun droit sur une table ne voit même pas qu'elle existe. Le script `01_gouvernance.sql` a ensuite créé le rôle qui écrit les règles sans lire les données, son schéma, les trois tags et la table des résultats de qualité, puis donné au rôle des outils le droit de poser les tags. Il est rejouable, et un test montre que le rôle de gouvernance est bien refusé sur `RAW`.

Le catalogue a suivi : une fiche par table, avec la description de chaque colonne et les tags. Les tags de sensibilité et de durée de conservation se posent sur la table et sont hérités par les colonnes ; le tag de donnée personnelle se pose colonne par colonne, y compris sur `driver_name`. La carte des droits a commencé à se remplir.

### Le deuxième jour : protéger

Quatre rôles métier ont été créés avec exactement les droits de la matrice du contrat : la paie, un responsable par dépôt (Queens, Bronx) et l'analyste. Un contrôle a montré sept droits chacun, aucun sur `RAW` ni `STAGING`. Un détail nous a appris quelque chose : quand l'administrateur lance un `GRANT` sur un objet d'un autre rôle, c'est le propriétaire de l'objet qui est enregistré comme donneur.

Puis vint la règle d'or : écrire les tests **avant** les politiques. Nous avons décidé à quoi ressemble une valeur masquée (`*****` pour un texte, `NULL` pour une date, sauf pour l'analyste, qui voit le premier janvier de l'année de naissance), calculé les volumes de référence par dépôt, et écrit pour chaque rôle ce qu'il doit voir. Ce cahier a été commité avant la première politique.

Le masquage a ensuite été écrit en deux politiques, une pour le texte et une pour les dates, attachées au tag de donnée personnelle plutôt qu'aux colonnes. Un rôle qui n'est pas cité voit toujours un masque. L'identifiant du chauffeur reste visible de tous, et le rôle des outils voit en clair. L'accès par dépôt repose sur une table de correspondance : ajouter un dépôt à un rôle est une ligne à insérer, sans toucher la politique. Nous avons décidé de l'attacher aussi aux deux tables de `RAW`, puisque le contrat les range parmi les tables du domaine RH.

Les tests ont ensuite été exécutés pour chaque rôle, administrateur et rôle de gouvernance compris. Vingt-cinq tests sur vingt-cinq étaient verts. Le cas le plus instructif est celui de l'administrateur : il ne reçoit pas un refus, il lit les tables par héritage, mais n'a aucune ligne dans la table de correspondance, donc il voit zéro ligne. La politique regarde le rôle actif, pas sa puissance. Nous avons relancé les six scripts du kit avec le rôle des outils : mêmes volumes, la paie lit toujours une vraie adresse, les politiques sont toujours attachées.

### Le troisième jour : conserver, contrôler, auditer

La purge supprime les chauffeurs dont la fin de contrat est antérieure à aujourd'hui moins cinq ans : 46 chauffeurs, qui n'avaient d'ailleurs aucun service dans le relevé. Les tables dérivées sont reconstruites ensuite (354 chauffeurs). Avant de limiter la rétention, nous avons prouvé le Time Travel : juste après la purge, la table pouvait encore être lue avec ses 400 lignes, dont les 46 supprimées. La rétention a ensuite été fixée à un jour sur les quatre tables (elle valait déjà un jour par défaut), et le stage est resté vide. Le délai réel de disparition d'une donnée est de huit jours.

Huit règles de qualité ont été écrites, chacune par une requête qui renvoie un seul nombre : six sont en alerte, deux sont respectées, dont la règle bloquante sur les services sans chauffeur connu (25 sur un seuil de 50). Une vue de catalogue, lisible à l'identique par l'analyste, décrit les 24 colonnes de `MARTS`. Trois tâches planifiées enchaînent la purge, le contrôle et la reconstruction : on ne reconstruit les tables que si le contrôle est passé. Le premier lancement de la tâche de qualité a échoué, parce qu'une sous-requête n'était pas permise dans une affectation ; la correction a laissé la trace de l'échec dans l'historique. Nous avons ensuite prouvé que la règle bloquante arrête vraiment le graphe, en abaissant son seuil à dix : le contrôle enregistre ses huit résultats, puis échoue, et la reconstruction ne part pas. Le seuil a été remis à cinquante.

Après une exécution complète, nous avons vérifié que tout avait survécu : volumes, tags, descriptions, politiques, masquage vu par l'analyste. Une requête d'audit croise l'historique des accès et celui des requêtes pour dire qui a lu la table des chauffeurs : huit lignes, dont les tâches, qui apparaissent sous un utilisateur système, et sans le rôle de gouvernance, dont les lectures avaient été refusées. Le lignage du mart a été capturé, puis le registre, la carte des droits et le README ont été complétés, avec l'ordre d'exécution en seize étapes et la liste des limites. Les tâches ont été suspendues, le bac à sable supprimé, et les CSV locaux envoyés à la corbeille.

### Ce que cela donne

Le dépôt contient un entrepôt gouverné de bout en bout : qui voit quoi, tranché par rôle et par dépôt ; pendant combien de temps, avec une purge et une rétention prouvées ; et jusqu'où on peut s'y fier, avec huit règles mesurées chaque jour et une règle qui arrête la reconstruction quand elle ne passe pas. Les limites sont écrites sans détour : le rôle des outils voit tout, l'administrateur peut s'attribuer un rôle métier, huit jours de Fail-safe, des dates qui restent en clair, une purge qui ne repose que sur la date de fin.

### Ce qu'il reste à faire

L'apprenant doit relire les documents, parce qu'il devra pouvoir les expliquer ; vider la corbeille pour supprimer définitivement les fichiers du personnel ; et pousser les deux derniers commits sur GitHub. La personne désignée pour la démonstration pourra s'appuyer sur les captures, sur les scripts de test et sur le README, qui décrit l'ordre exécutable de tout le projet.
