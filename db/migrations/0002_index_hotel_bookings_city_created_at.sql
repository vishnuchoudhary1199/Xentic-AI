-- migrate:no-transaction
--
-- 0002: index for the city + recent-bookings report:
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- * city first (equality), created_at second (range): the scan starts at
--   ('delhi', now-30d) and reads one contiguous slice of the index.
-- * INCLUDE (org_id, status, amount) makes it a covering index, so the query is
--   answered by an Index Only Scan without visiting the table heap.
--
-- CONCURRENTLY avoids blocking writes on a live table, which is why this file
-- runs outside a transaction. See README "Query optimisation" for EXPLAIN output.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
