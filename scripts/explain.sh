#!/usr/bin/env bash
#
# Show the execution plan of the Delhi report query, with and without the index.
#
#   ./scripts/explain.sh          # plan using idx_hotel_bookings_city_created_at
#   ./scripts/explain.sh --compare  # also show the plan with the index disabled
#
# The "without index" plan is produced inside a transaction that drops the index
# and is then rolled back, so nothing is changed.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

QUERY="SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status"

ensure_running db

# Make sure statistics and the visibility map are current (index-only scans
# need the visibility map to skip heap fetches).
psql_in db "${POSTGRES_DB}" -c "VACUUM (ANALYZE) hotel_bookings;"

echo "=== Row count: $(psql_in db "${POSTGRES_DB}" -tAc 'SELECT count(*) FROM hotel_bookings') bookings"
echo
echo "=== WITH index"
psql_in db "${POSTGRES_DB}" -c "EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON) ${QUERY};"

if [[ "${1:-}" == "--compare" ]]; then
  echo "=== WITHOUT index (dropped inside a transaction, then rolled back)"
  psql_in db "${POSTGRES_DB}" <<SQL
BEGIN;
DROP INDEX idx_hotel_bookings_city_created_at;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON) ${QUERY};
ROLLBACK;
SQL
fi
