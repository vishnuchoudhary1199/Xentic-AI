#!/usr/bin/env bash
#
# Apply pending migrations (db/migrations) to the running local database.
# Pass --seed to also (re)run the idempotent seed files.
#
# Migrations and seed already run automatically on the first `docker compose up`;
# use this for migrations added later or after `docker compose down -v`.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SEED=false
[[ "${1:-}" == "--seed" ]] && SEED=true

ensure_running db
compose exec -T -e SEED="${SEED}" db sh /db/migrate.sh
