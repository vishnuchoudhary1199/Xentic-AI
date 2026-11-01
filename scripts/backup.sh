#!/usr/bin/env bash
#
# Create a timestamped, verified dump of the local PostgreSQL database.
#
#   ./scripts/backup.sh                 # backs up $POSTGRES_DB (default: bookings)
#   ./scripts/backup.sh -d bookings -o ./backups -k 14
#
# Produces, in the backup directory:
#   <db>_<YYYYMMDDTHHMMSSZ>.dump      pg_dump custom format (compressed, selective restore)
#   <db>_<YYYYMMDDTHHMMSSZ>.sha256    checksum, verify with: sha256sum -c <file>.sha256
#   <db>_<YYYYMMDDTHHMMSSZ>.manifest  row count + md5 per table, used by restore.sh
#
# Consistency: the dump and the manifest are taken from the SAME exported
# snapshot (pg_export_snapshot + pg_dump --snapshot), so the manifest describes
# exactly what is inside the dump even while the database is taking writes.
#
# Only Docker is required on the host; pg_dump runs inside the db container,
# so the client version always matches the server.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d database] [-o backup_dir] [-k keep]

  -d  database to back up        (default: ${POSTGRES_DB})
  -o  directory for backups      (default: ${BACKUP_DIR})
  -k  dumps of this db to keep   (default: ${BACKUP_KEEP}, 0 = keep all)
EOF
}

DB="${POSTGRES_DB}"
while getopts ":d:o:k:h" opt; do
  case "${opt}" in
    d) DB="${OPTARG}" ;;
    o) BACKUP_DIR="${OPTARG}" ;;
    k) BACKUP_KEEP="${OPTARG}" ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ "${BACKUP_KEEP}" =~ ^[0-9]+$ ]] || die "-k must be a non-negative integer"

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

ensure_running db
mkdir -p "${BACKUP_DIR}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="${BACKUP_DIR}/${DB}_${TS}"
DUMP="${BASE}.dump"
PARTIAL="${DUMP}.partial"

cleanup() {
  rm -f "${PARTIAL}"
  if [[ -n "${SNAP_PID:-}" ]]; then
    { echo "ROLLBACK;" >&3; } 2>/dev/null || true
    kill "${SNAP_PID}" 2>/dev/null || true
  fi
  exec 3>&- 4<&- 2>/dev/null || true
  rm -rf "${FIFO_DIR:-}"
}
trap cleanup EXIT

# 1. Open a read-only REPEATABLE READ transaction and export its snapshot.
#    A background psql session (talked to through two FIFOs, which works on
#    the bash 3.2 that ships with macOS) keeps it open until the dump is done.
FIFO_DIR="$(mktemp -d)"
mkfifo "${FIFO_DIR}/in" "${FIFO_DIR}/out"
psql_in db "${DB}" -tA < "${FIFO_DIR}/in" > "${FIFO_DIR}/out" 2>&1 &
SNAP_PID=$!
exec 3> "${FIFO_DIR}/in" 4< "${FIFO_DIR}/out"

echo "BEGIN ISOLATION LEVEL REPEATABLE READ, READ ONLY; SELECT pg_export_snapshot();" >&3
read -r -t 30 SNAPSHOT <&4 || die "could not export a snapshot from database '${DB}'"
[[ "${SNAPSHOT}" =~ ^[0-9A-F-]+$ ]] || die "unexpected response while exporting snapshot: ${SNAPSHOT}"
log "exported snapshot ${SNAPSHOT}"

# 2. Fingerprint every table inside that snapshot -> manifest.
cat "${ROOT_DIR}/scripts/sql/fingerprint.sql" >&3
echo "SELECT '__END__';" >&3
MANIFEST_ROWS=()
while read -r -t 300 line <&4; do
  [[ "${line}" == "__END__" ]] && break
  MANIFEST_ROWS+=("${line}")
done
[[ ${#MANIFEST_ROWS[@]} -gt 0 ]] || die "manifest is empty - does database '${DB}' have any tables?"

# 3. Dump from the same snapshot.
log "dumping '${DB}' -> ${DUMP}"
compose exec -T db pg_dump \
  -U "${POSTGRES_USER}" -d "${DB}" \
  --snapshot="${SNAPSHOT}" \
  --format=custom --compress=6 \
  --no-owner --no-privileges \
  > "${PARTIAL}"

echo "COMMIT;" >&3
exec 3>&-
wait "${SNAP_PID}" 2>/dev/null || true
unset SNAP_PID

# 4. Verify the archive is readable before declaring success.
[[ -s "${PARTIAL}" ]] || die "pg_dump produced an empty file"
OBJECTS="$(compose exec -T db pg_restore --list < "${PARTIAL}" | grep -vc '^;' || true)"
[[ "${OBJECTS}" -gt 0 ]] || die "dump failed verification (pg_restore --list found no objects)"
mv "${PARTIAL}" "${DUMP}"

{
  echo "# database:   ${DB}"
  echo "# created_at: ${TS}"
  echo "# snapshot:   ${SNAPSHOT}"
  echo "# server:     $(psql_in db "${DB}" -tAc 'SHOW server_version')"
  echo "# format:     table|row_count|md5(all rows)"
  printf '%s\n' "${MANIFEST_ROWS[@]}"
} > "${BASE}.manifest"

(cd "${BACKUP_DIR}" && sha256 "$(basename "${DUMP}")" > "$(basename "${BASE}").sha256")

# 5. Retention: keep the newest N dumps of this database (names sort by time).
if [[ "${BACKUP_KEEP}" -gt 0 ]]; then
  find "${BACKUP_DIR}" -maxdepth 1 -name "${DB}_*.dump" -print | sort -r | tail -n "+$((BACKUP_KEEP + 1))" |
    while read -r old; do
      log "retention: removing $(basename "${old}")"
      rm -f "${old}" "${old%.dump}.sha256" "${old%.dump}.manifest"
    done
fi

SIZE="$(du -h "${DUMP}" | cut -f1)"
log "backup OK: ${DUMP} (${SIZE}, ${OBJECTS} archive entries)"
printf '  %-20s %10s\n' "table" "rows" >&2
for row in "${MANIFEST_ROWS[@]}"; do
  IFS='|' read -r t n _ <<<"${row}"
  printf '  %-20s %10s\n' "${t}" "${n}" >&2
done

# Machine-readable result on stdout: the dump path.
echo "${DUMP}"
