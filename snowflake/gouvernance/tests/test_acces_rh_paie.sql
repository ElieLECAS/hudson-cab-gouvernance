-- =====================================================================
-- test_acces_rh_paie.sql — les tests du cahier (docs/ACCES.md, partie 2) pour le rôle RH_PAIE.
-- À exécuter en entier (Ctrl+Maj+Entrée) : il change de rôle lui-même et renvoie une table,
-- une ligne par test : « numéro | résultat obtenu ». Une requête refusée donne « ERREUR : … » (résultat attendu
-- quand le cahier prévoit un refus). Les valeurs de personnes ne sont jamais affichées : « clair », « masqué ».
-- Lecture seule : ce script ne modifie rien.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
EXECUTE IMMEDIATE $$
DECLARE
  arr ARRAY DEFAULT ARRAY_CONSTRUCT();
  v VARCHAR;
BEGIN
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, '1 | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '1 | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
    arr := ARRAY_APPEND(arr, '8 | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '8 | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(email LIKE '%@%', 'vraie adresse', 'masquée')), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, '11 email de D0003 | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '11 email de D0003 | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
    arr := ARRAY_APPEND(arr, 'lignes MART | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'lignes MART | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(driver_id = 'D0003', 'clair', 'masqué')), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V driver_id | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V driver_id | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(first_name = '*****' AND last_name = '*****', 'masqué', IFF(first_name <> '*****' AND last_name <> '*****', 'clair', 'mixte'))), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V nom et prénom | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V nom et prénom | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(email IS NULL, 'NULL', IFF(email = '*****', 'masqué', 'clair'))), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V email | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V email | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(phone IS NULL, 'NULL', IFF(phone = '*****', 'masqué', 'clair'))), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V téléphone | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V téléphone | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(birth_date IS NULL, 'NULL', IFF(MONTH(birth_date) = 1 AND DAY(birth_date) = 1, '1er janvier', 'date complète'))), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V date de naissance | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V date de naissance | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(tlc_license_number IS NULL, 'NULL', IFF(tlc_license_number = '*****', 'masqué', 'clair'))), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V numéro de licence | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V numéro de licence | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COALESCE(MAX(IFF(driver_name IS NULL, 'NULL', IFF(driver_name = '*****', 'masqué', 'clair'))), 'ligne invisible') INTO :v FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_id = 'D0003';
    arr := ARRAY_APPEND(arr, 'V driver_name (mart) | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'V driver_name (mart) | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  LET rs RESULTSET := (SELECT value::VARCHAR AS resultat FROM TABLE(FLATTEN(INPUT => :arr)) ORDER BY index);
  RETURN TABLE(rs);
END;
$$;
