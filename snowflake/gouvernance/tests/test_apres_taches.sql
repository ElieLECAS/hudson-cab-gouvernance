-- =====================================================================
-- test_apres_taches.sql — étape 3.7 : les règles ont-elles survécu à l'exécution des tâches ? Rôle TRANSFORMER.
-- À lancer après une exécution réussie du graphe T_PURGE → T_QUALITE → T_TABLES. Lecture seule.
-- Il renvoie une table, une ligne par contrôle. Volumes après la purge : DIM_DRIVER 354 (400 − 46 chauffeurs purgés).
-- Les politiques attachées se contrôlent avec test_12_politiques_attachees.sql (GOUVERNANCE) et le masquage vu par
-- l'analyste avec test_acces_analyste.sql : TRANSFORMER, lui, ne peut pas lire POLICY_REFERENCES.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
EXECUTE IMMEDIATE $$
DECLARE
  arr ARRAY DEFAULT ARRAY_CONSTRUCT();
  v VARCHAR;
BEGIN
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, 'DIM_DRIVER (attendu 354) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'DIM_DRIVER | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
    arr := ARRAY_APPEND(arr, 'MART_DRIVER_MONTHLY (attendu 914) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'MART_DRIVER_MONTHLY | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DEPOT;
    arr := ARRAY_APPEND(arr, 'DIM_DEPOT (attendu 3) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'DIM_DEPOT | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  -- Les tâches n'ont recopié aucun masque : le rôle des outils lit en clair
  BEGIN
    SELECT (COUNT_IF(first_name = '*****') + COUNT_IF(last_name = '*****') + COUNT_IF(email = '*****')
            + COUNT_IF(phone = '*****') + COUNT_IF(tlc_license_number = '*****'))::VARCHAR INTO :v
    FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, 'masques recopiés dans DIM_DRIVER (attendu 0) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'masques dans DIM_DRIVER | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT_IF(driver_name = '*****')::VARCHAR || ' masqués, ' || COUNT_IF(driver_name IS NULL)::VARCHAR || ' vides' INTO :v
    FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
    arr := ARRAY_APPEND(arr, 'driver_name du mart (attendu 0 masqués, 25 vides) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'driver_name du mart | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  -- Les tags sont toujours là : DONNEE_PERSONNELLE sur 7 colonnes de DIM_DRIVER, 2 du mart
  BEGIN
    SELECT COUNT_IF(tag_name = 'DONNEE_PERSONNELLE')::VARCHAR INTO :v
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'));
    arr := ARRAY_APPEND(arr, 'tags DONNEE_PERSONNELLE sur DIM_DRIVER (attendu 7) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'tags DIM_DRIVER | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT_IF(tag_name = 'DONNEE_PERSONNELLE')::VARCHAR INTO :v
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'));
    arr := ARRAY_APPEND(arr, 'tags DONNEE_PERSONNELLE sur le mart (attendu 2) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'tags mart | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT_IF(tag_name = 'DONNEE_PERSONNELLE')::VARCHAR INTO :v
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVERS', 'table'));
    arr := ARRAY_APPEND(arr, 'tags DONNEE_PERSONNELLE sur RAW.DRIVERS (attendu 7) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'tags RAW.DRIVERS | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  -- Les descriptions sont toujours là : aucune colonne sans description dans DIM_DEPOT, DIM_DRIVER, RAW.DRIVERS
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v
    FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
    WHERE ((table_schema = 'MARTS' AND table_name IN ('DIM_DEPOT', 'DIM_DRIVER')) OR (table_schema = 'RAW' AND table_name = 'DRIVERS'))
      AND comment IS NULL;
    arr := ARRAY_APPEND(arr, 'colonnes sans description (attendu 0) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'descriptions | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT_IF(comment IS NOT NULL)::VARCHAR INTO :v
    FROM NYC_TAXI.INFORMATION_SCHEMA.TABLES
    WHERE (table_schema, table_name) IN (('RAW', 'DRIVERS'), ('RAW', 'DRIVER_SHIFTS'), ('MARTS', 'DIM_DRIVER'),
                                        ('MARTS', 'MART_DRIVER_MONTHLY'), ('MARTS', 'DIM_DEPOT'));
    arr := ARRAY_APPEND(arr, 'tables RH avec description (attendu 5) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'descriptions de tables | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  LET rs RESULTSET := (SELECT value::VARCHAR AS resultat FROM TABLE(FLATTEN(INPUT => :arr)) ORDER BY index);
  RETURN TABLE(rs);
END;
$$;
