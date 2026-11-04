-- =====================================================================
-- test_acces_sysadmin.sql — les tests du cahier (docs/ACCES.md, partie 2) pour le rôle SYSADMIN.
-- À exécuter en entier (Ctrl+Maj+Entrée) : il change de rôle lui-même et renvoie une table,
-- une ligne par test : « numéro | résultat obtenu ». Une requête refusée donne « ERREUR : … » (résultat attendu
-- quand le cahier prévoit un refus). Les valeurs de personnes ne sont jamais affichées : « clair », « masqué ».
-- Lecture seule : ce script ne modifie rien.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE SYSADMIN;
USE WAREHOUSE NYC_TAXI_WH;
EXECUTE IMMEDIATE $$
DECLARE
  arr ARRAY DEFAULT ARRAY_CONSTRUCT();
  v VARCHAR;
BEGIN
  BEGIN
    SELECT COUNT(*)::VARCHAR INTO :v FROM NYC_TAXI.MARTS.DIM_DRIVER;
    arr := ARRAY_APPEND(arr, '15 | ' || COALESCE(v, 'NULL'));
  EXCEPTION WHEN OTHER THEN
    arr := ARRAY_APPEND(arr, '15 | ERREUR : ' || LEFT(SQLERRM, 100));
  END;
  LET rs RESULTSET := (SELECT value::VARCHAR AS resultat FROM TABLE(FLATTEN(INPUT => :arr)) ORDER BY index);
  RETURN TABLE(rs);
END;
$$;
