-- =====================================================================
-- test_acces_gouvernance.sql — les tests du cahier (docs/ACCES.md, partie 2) pour le rôle GOUVERNANCE.
-- À exécuter en entier (Ctrl+Maj+Entrée) : il change de rôle lui-même et renvoie une table,
-- une ligne par test : « numéro | résultat obtenu ». Une requête refusée donne « ERREUR : … » (résultat attendu
-- quand le cahier prévoit un refus). Les valeurs de personnes ne sont jamais affichées : « clair », « masqué ».
-- Lecture seule : ce script ne modifie rien.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;
EXECUTE IMMEDIATE $$
DECLARE
  arr ARRAY DEFAULT ARRAY_CONSTRUCT();
  v VARCHAR;
BEGIN
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, '6 | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '6 | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT;
    arr := ARRAY_APPEND(arr, '19 ACCES_DEPOT | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '19 ACCES_DEPOT | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.RAW.DRIVERS;
    arr := ARRAY_APPEND(arr, 'RAW.DRIVERS | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, 'RAW.DRIVERS | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  LET rs RESULTSET := (SELECT value::VARCHAR AS resultat FROM TABLE(FLATTEN(INPUT => :arr)) ORDER BY index);
  RETURN TABLE(rs);
END;
$$;
