#!/usr/bin/env bash
#
# Restore a dump made by backup.sh into a FRESH database and prove it worked.
#
#   ./scripts/restore.sh                         # newest dump -> new database "<db>_restored"
#   ./scripts/restore.sh backups/bookings_20260101T000000Z.dump
#   ./scripts/restore.sh -t bookings_dr_test     # choose the target database name
#   ./scripts/restore.sh --new-server            # restore into a separate, empty
#                                                # PostgreSQL container (restore-db)
#
# Steps: verify sha256 -> drop/create the target database -> pg_restore in a
# single transaction (all or nothing) -> ANALYZE -> compare the row count and
# md5 of every table with the .manifest recorded at backup time.
# Exits non-zero if anything differs.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-t target_db] [--new-server] [--force] [dump_file]

  dump_file       dump to restore (default: newest *.dump in ${BACKUP_DIR})
  -t, --target    database to (re)create   (default: ${POSTGRES_DB}_restored,
                                            or ${POSTGRES_DB} with --new-server)
  --new-server    restore into the separate empty 'restore-db' container
                  (port ${RESTORE_POSTGRES_PORT:-5433}) instead of a new database on 'db'
  --force         allow overwriting the live source database '${POSTGRES_DB}' on 'db'
EOF
}

TARGET=""
SERVICE="db"
FORCE=false
DUMP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target) TARGET="${2:?--target needs a value}"; shift 2 ;;
    --new-server) SERVICE="restore-db"; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *) DUMP="$1"; shift ;;
  esac
done

# Resolve inputs

if [[ -z "${DUMP}" ]]; then
  DUMP="$(find "${BACKUP_DIR}" -maxdepth 1 -name '*.dump' -print 2>/dev/null | sort | tail -n 1)"
  [[ -n "${DUMP}" ]] || die "no dumps found in ${BACKUP_DIR} - run ./scripts/backup.sh first"
fi
[[ -f "${DUMP}" ]] || die "dump file not found: ${DUMP}"
BASE="${DUMP%.dump}"

if [[ -z "${TARGET}" ]]; then
  if [[ "${SERVICE}" == "restore-db" ]]; then TARGET="${POSTGRES_DB}"; else TARGET="${POSTGRES_DB}_restored"; fi
fi
[[ "${TARGET}" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || die "invalid target database name: ${TARGET}"
case "${TARGET}" in postgres|template0|template1) die "refusing to overwrite system database ${TARGET}" ;; esac
if [[ "${SERVICE}" == "db" && "${TARGET}" == "${POSTGRES_DB}" && "${FORCE}" != true ]]; then
  die "target '${TARGET}' is the live source database; pass --force to overwrite it"
fi

log "dump:   ${DUMP}"
log "target: database '${TARGET}' on service '${SERVICE}'"

# 1. Integrity

if [[ -f "${BASE}.sha256" ]]; then
  if command -v sha256sum >/dev/null; then CHECK=(sha256sum -c --status); else CHECK=(shasum -a 256 -c -s); fi
  (cd "$(dirname "${DUMP}")" && "${CHECK[@]}" "$(basename "${BASE}").sha256") \
    || die "checksum mismatch: ${DUMP} is corrupt or was modified"
  log "checksum OK"
else
  log "warning: no .sha256 next to the dump, skipping checksum verification"
fi

# 2. Fresh target database

[[ "${SERVICE}" == "restore-db" ]] && export COMPOSE_PROFILES=restore
ensure_running "${SERVICE}"

log "recreating database '${TARGET}'"
psql_in "${SERVICE}" postgres -c "SET client_min_messages = warning" \
  -c "DROP DATABASE IF EXISTS \"${TARGET}\" WITH (FORCE);"
psql_in "${SERVICE}" postgres -c "CREATE DATABASE \"${TARGET}\" TEMPLATE template0 ENCODING 'UTF8';"

# 3. Restore

log "restoring (single transaction)"
START=$(date +%s)
compose exec -T "${SERVICE}" pg_restore \
  -U "${POSTGRES_USER}" -d "${TARGET}" \
  --no-owner --no-privileges \
  --exit-on-error --single-transaction \
  < "${DUMP}"
psql_in "${SERVICE}" "${TARGET}" -c "ANALYZE;"
log "restore finished in $(( $(date +%s) - START ))s"

# 4. Verify

ACTUAL="$(fingerprint "${SERVICE}" "${TARGET}")"

if [[ -f "${BASE}.manifest" ]]; then
  EXPECTED="$(grep -v '^#' "${BASE}.manifest")"
  SOURCE_DESC="manifest recorded at backup time"
else
  log "warning: no .manifest for this dump; comparing with the live source database instead"
  EXPECTED="$(fingerprint db "${POSTGRES_DB}")"
  SOURCE_DESC="live database '${POSTGRES_DB}'"
fi

STATUS=0
printf '\n  Verification against %s\n' "${SOURCE_DESC}" >&2
printf '  %-20s %12s %12s  %s\n' "table" "expected" "restored" "result" >&2
while IFS='|' read -r table rows sum; do
  [[ -n "${table}" ]] || continue
  actual_line="$(printf '%s\n' "${ACTUAL}" | grep "^${table}|" || true)"
  IFS='|' read -r _ a_rows a_sum <<<"${actual_line}"
  if [[ -z "${actual_line}" ]]; then
    result="MISSING"; STATUS=1
  elif [[ "${rows}" != "${a_rows}" || "${sum}" != "${a_sum}" ]]; then
    result="MISMATCH"; STATUS=1
  else
    result="OK (md5 match)"
  fi
  printf '  %-20s %12s %12s  %s\n' "${table}" "${rows}" "${a_rows:--}" "${result}" >&2
done <<<"${EXPECTED}"
echo >&2

if [[ "${STATUS}" -ne 0 ]]; then
  die "restore verification FAILED for database '${TARGET}'"
fi

PORT="${POSTGRES_PORT:-5432}"
[[ "${SERVICE}" == "restore-db" ]] && PORT="${RESTORE_POSTGRES_PORT:-5433}"
log "restore verified: '${TARGET}' is identical to the backup"
log "inspect it: docker compose exec ${SERVICE} psql -U ${POSTGRES_USER} -d ${TARGET}"
log "        or: psql postgresql://${POSTGRES_USER}@127.0.0.1:${PORT}/${TARGET}"
