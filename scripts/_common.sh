# Shared helpers for the database scripts. Sourced, not executed.
# shellcheck shell=bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load overrides from .env (same file docker compose reads).
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-bookings}"
POSTGRES_DB="${POSTGRES_DB:-bookings}"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
[[ "${BACKUP_DIR}" = /* ]] || BACKUP_DIR="${ROOT_DIR}/${BACKUP_DIR#./}"
BACKUP_KEEP="${BACKUP_KEEP:-7}"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker is not installed or not on PATH"
docker compose version >/dev/null 2>&1 || die "the docker compose plugin (v2) is required"

compose() {
  docker compose --project-directory "${ROOT_DIR}" -f "${ROOT_DIR}/docker-compose.yml" "$@"
}

# psql_in <service> <database> [psql args...]  - non-interactive psql inside a container
psql_in() {
  local service="$1" db="$2"
  shift 2
  compose exec -T "${service}" psql --no-psqlrc -v ON_ERROR_STOP=1 -q -U "${POSTGRES_USER}" -d "${db}" "$@"
}

# Wait until a compose service reports healthy (starts it if needed).
# Profile-gated services (restore-db) need COMPOSE_PROFILES set by the caller.
ensure_running() {
  local service="$1"
  if ! compose ps --status running --services 2>/dev/null | grep -qx "${service}"; then
    log "starting ${service}"
    compose up -d "${service}" >/dev/null 2>&1 || die "could not start ${service} (try: docker compose up ${service})"
  fi
  for _ in $(seq 1 60); do
    if compose exec -T "${service}" pg_isready -q -U "${POSTGRES_USER}" -d postgres 2>/dev/null; then
      # pg_isready is true during first-boot init too; wait for the init to finish.
      if [[ "$(compose ps --format '{{.Health}}' "${service}" 2>/dev/null)" == "healthy" ]]; then
        return 0
      fi
    fi
    sleep 1
  done
  die "${service} did not become healthy in 60s (check: docker compose logs ${service})"
}

# fingerprint <service> <database>  -> "table|rows|md5" lines
fingerprint() {
  psql_in "$1" "$2" -tA < "${ROOT_DIR}/scripts/sql/fingerprint.sql"
}
