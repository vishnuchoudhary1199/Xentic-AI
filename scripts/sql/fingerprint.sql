-- Prints one line per table in the public schema:  table|row_count|md5
-- The md5 covers every column of every row (rows sorted by their text form),
-- so two databases with identical fingerprints hold identical data.
-- Used by backup.sh (written to the .manifest) and restore.sh (verification).
SELECT format(
    'SELECT %L, count(*), md5(coalesce(string_agg(t::text, E''\n'' ORDER BY t::text), '''')) FROM %I.%I AS t',
    tablename, schemaname, tablename
)
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename
\gexec
