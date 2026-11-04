-- =====================================================================
-- test_apres_relance_pipeline.sql — test 10 du cahier (docs/ACCES.md, partie 2), avec TRANSFORMER.
-- À lancer APRÈS avoir relancé les six fichiers SQL du kit (étape 2.8). Il renvoie une table, une ligne par test.
-- Le test 11 (RH_PAIE lit toujours une vraie adresse e-mail) est dans test_acces_rh_paie.sql ; le test 12
-- (politiques toujours attachées) dans test_12_politiques_attachees.sql, avec GOUVERNANCE.
-- Lecture seule : ce script ne modifie rien.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
EXECUTE IMMEDIATE $$
DECLARE
  arr ARRAY DEFAULT ARRAY_CONSTRUCT();
  v VARCHAR;
BEGIN
  -- Les volumes : les mêmes qu'avant la relance
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.STAGING.STG_RH__DRIVER_SHIFTS;
    arr := ARRAY_APPEND(arr, '10 STG_RH__DRIVER_SHIFTS (attendu 25933) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '10 STG_RH__DRIVER_SHIFTS | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DEPOT;
    arr := ARRAY_APPEND(arr, '10 DIM_DEPOT (attendu 3) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '10 DIM_DEPOT | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, '10 DIM_DRIVER (attendu 400) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '10 DIM_DRIVER | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
    arr := ARRAY_APPEND(arr, '10 MART_DRIVER_MONTHLY (attendu 914) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '10 MART_DRIVER_MONTHLY | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  -- Le pipeline n'a recopié aucun masque : aucune valeur '*****' dans les tables, et driver_name vide seulement
  -- pour les 25 services de chauffeurs inconnus
  BEGIN
    SELECT (COUNT_IF(first_name = '*****') + COUNT_IF(last_name = '*****') + COUNT_IF(email = '*****')
            + COUNT_IF(phone = '*****') + COUNT_IF(tlc_license_number = '*****'))::VARCHAR INTO :v
    FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, '10 masques recopiés dans DIM_DRIVER (attendu 0) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '10 masques dans DIM_DRIVER | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT_IF(driver_name = '*****')::VARCHAR || ' masqués, ' || COUNT_IF(driver_name IS NULL)::VARCHAR || ' vides' INTO :v
    FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
    arr := ARRAY_APPEND(arr, '10 driver_name du mart (attendu 0 masqués, 25 vides) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '10 driver_name du mart | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  LET rs RESULTSET := (SELECT value::VARCHAR AS resultat FROM TABLE(FLATTEN(INPUT => :arr)) ORDER BY index);
  RETURN TABLE(rs);
END;
$$;
