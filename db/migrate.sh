#!/bin/sh
# Minimal, dependency-free migration runner (runs inside the postgres container).
#
# * Applies db/migrations/*.sql in lexical order, each exactly once, and records
#   it in schema_migrations.
# * Each migration runs in a single transaction together with its bookkeeping
#   row, unless the file contains the marker "migrate:no-transaction" (needed
#   for CREATE INDEX CONCURRENTLY).
# * With SEED=true, then runs db/seed/*.sql (seed files are idempotent).
#
# Connects over the local unix socket as $POSTGRES_USER to $POSTGRES_DB.
set -eu

MIGRATIONS_DIR="${MIGRATIONS_DIR:-/db/migrations}"
SEED_DIR="${SEED_DIR:-/db/seed}"
SEED="${SEED:-false}"
DB_USER="${POSTGRES_USER:?POSTGRES_USER not set}"
DB_NAME="${POSTGRES_DB:-$DB_USER}"

psql_run() {
  PGOPTIONS="-c client_min_messages=warning" \
  psql --no-psqlrc -v ON_ERROR_STOP=1 -q -U "$DB_USER" -d "$DB_NAME" "$@"
}

psql_run -c "CREATE TABLE IF NOT EXISTS schema_migrations (
  version    TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);"

applied=0
for file in "$MIGRATIONS_DIR"/*.sql; do
  [ -e "$file" ] || continue
  version="$(basename "$file" .sql)"

  if [ -n "$(psql_run -tA -c "SELECT 1 FROM schema_migrations WHERE version = '$version'")" ]; then
    continue
  fi

  echo "migrate: applying $version"
  record="INSERT INTO schema_migrations (version) VALUES ('$version');"
  if grep -q 'migrate:no-transaction' "$file"; then
    psql_run -f "$file"
    psql_run -c "$record"
  else
    psql_run --single-transaction -f "$file" -c "$record"
  fi
  applied=$((applied + 1))
done
echo "migrate: $applied migration(s) applied, schema is up to date"

if [ "$SEED" = "true" ]; then
  for file in "$SEED_DIR"/*.sql; do
    [ -e "$file" ] || continue
    echo "seed: running $(basename "$file")"
    psql_run --single-transaction -f "$file"
  done
fi
