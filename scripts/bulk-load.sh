#!/usr/bin/env bash
#
# OPTIONAL: add N synthetic bookings (default 1000000) so EXPLAIN shows how the
# index behaves at a realistic table size. The 1,200 seed rows are small enough
# that PostgreSQL may legitimately prefer a sequential scan.
#
#   ./scripts/bulk-load.sh 1000000 && ./scripts/explain.sh --compare
#
# Rows use ids in a separate namespace, so the script is idempotent per N.
set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

ROWS="${1:-1000000}"
[[ "${ROWS}" =~ ^[0-9]+$ ]] || die "usage: $0 [rows]"

ensure_running db
log "inserting up to ${ROWS} synthetic bookings"
psql_in db "${POSTGRES_DB}" -v rows="${ROWS}" <<'SQL'
INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    md5('bulk-' || g)::uuid,
    md5('org-' || (1 + mod(abs(hashtext('bo' || g)), 50)))::uuid,
    'HTL-BULK-' || lpad(mod(abs(hashtext('bh' || g)), 500)::text, 3, '0'),
    (ARRAY['delhi','mumbai','bengaluru','chennai','kolkata','hyderabad','pune','jaipur','goa','kochi',
           'lucknow','indore','ahmedabad','surat','nagpur','bhopal','patna','agra','udaipur','shimla'])
        [1 + mod(abs(hashtext('bc' || g)), 20)],
    d.created::date + 7,
    d.created::date + 7 + 1 + mod(abs(hashtext('bn' || g)), 6),
    round((1500 + mod(abs(hashtext('ba' || g)), 20000))::numeric, 2),
    (ARRAY['pending','confirmed','completed','cancelled','refunded'])[1 + mod(abs(hashtext('bs' || g)), 5)],
    d.created
FROM generate_series(1, :rows) AS g
CROSS JOIN LATERAL (
    -- two years of history, so "last 30 days" is a small slice (~4%) of the table
    SELECT date_trunc('second', now()::timestamp) - make_interval(secs => mod(abs(hashtext('bt' || g)), 730 * 86400)) AS created
) AS d
ON CONFLICT (id) DO NOTHING;
SQL
psql_in db "${POSTGRES_DB}" -c "VACUUM (ANALYZE) hotel_bookings;"
log "done: $(psql_in db "${POSTGRES_DB}" -tAc 'SELECT count(*) FROM hotel_bookings') bookings in total"
