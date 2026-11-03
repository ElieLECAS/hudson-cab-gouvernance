# Hudson Cab Partners : gouverner l'entrepôt NYC Taxi

Projet de formation (Data Engineer). Hudson Cab Partners exploite une flotte de taxis jaunes à New York, avec trois dépôts : Bronx, Brooklyn et Queens. Son entrepôt Snowflake contient maintenant le fichier du personnel (400 chauffeurs, fictifs) et le relevé de leurs services de janvier à mars 2025. Personne ne s'est encore demandé qui avait le droit de lire ces données, ni combien de temps on pouvait les garder.

Ce dépôt répond à une seule question : qui peut voir quelle donnée, pendant combien de temps, et peut-on s'y fier ?

## Où en est le projet

| Étape | État |
|---|---|
| Veille réglementaire (`docs/VEILLE.md`) | rédigée |
| Inventaire des données personnelles (`docs/REGISTRE.md`, partie 1) | fait |
| Chargement du fichier dans `RAW`, rôles, catalogue | à faire |
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

À compléter : masquer ou supprimer une colonne, purge des services d'un chauffeur parti, durée de conservation par table.

### Ordre d'exécution

À compléter une fois les scripts écrits et rejoués de bout en bout.

### Limites connues

À compléter en fin de projet.
