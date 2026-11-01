-- Seed data: 1,200 hotel bookings + their events.
--
-- * Deterministic: ids are derived from md5(), and every "random" choice is a
--   hash of the row number, so every run produces the same bookings with the same ids.
-- * Idempotent: safe to run repeatedly (ON CONFLICT / NOT EXISTS guards).
-- * created_at is spread over the last 120 days relative to now(), so the
--   "last 30 days in delhi" report always returns rows.
--
-- Coverage: 12 organisations, 9 cities (delhi weighted ~20%), 5 statuses,
-- ~80% of bookings have 1-3 events, the rest have none.

\set booking_count 1200

INSERT INTO hotel_bookings (
    id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at
)
SELECT
    md5('booking-' || g)::uuid                                          AS id,
    md5('org-' || (1 + h.org_n))::uuid                                  AS org_id,
    'HTL-' || upper(left(c.city, 3)) || '-' || lpad((1 + h.hotel_n)::text, 3, '0') AS hotel_id,
    c.city,
    (b.created_at)::date + h.lead_days                                  AS checkin_date,
    (b.created_at)::date + h.lead_days + h.nights                       AS checkout_date,
    round(h.nights * h.nightly_rate, 2)                                 AS amount,
    s.status,
    b.created_at
FROM generate_series(1, :booking_count) AS g
CROSS JOIN LATERAL (
    SELECT
        mod(abs(hashtext('org'    || g)), 12)      AS org_n,
        mod(abs(hashtext('city'   || g)), 10)      AS city_n,
        mod(abs(hashtext('hotel'  || g)), 25)      AS hotel_n,
        mod(abs(hashtext('status' || g)), 20)      AS status_n,
        1  + mod(abs(hashtext('lead'   || g)), 60) AS lead_days,
        1  + mod(abs(hashtext('nights' || g)), 7)  AS nights,
        1500 + mod(abs(hashtext('rate' || g)), 13500) + 0.99 AS nightly_rate,
        mod(abs(hashtext('age'    || g)), 120 * 24 * 60) AS age_minutes
) AS h
CROSS JOIN LATERAL (
    SELECT date_trunc('minute', now()::timestamp) - make_interval(mins => h.age_minutes) AS created_at
) AS b
CROSS JOIN LATERAL (
    SELECT (ARRAY[
        'delhi', 'delhi', 'mumbai', 'bengaluru', 'chennai',
        'kolkata', 'hyderabad', 'pune', 'jaipur', 'goa'
    ])[1 + h.city_n] AS city
) AS c
CROSS JOIN LATERAL (
    -- Weighted: confirmed 40%, completed 20%, pending 15%, cancelled 15%, refunded 10%.
    SELECT CASE
        WHEN h.status_n < 8  THEN 'confirmed'
        WHEN h.status_n < 12 THEN 'completed'
        WHEN h.status_n < 15 THEN 'pending'
        WHEN h.status_n < 18 THEN 'cancelled'
        ELSE 'refunded'
    END AS status
) AS s
ON CONFLICT (id) DO NOTHING;

-- Events: every booking gets "booking.created"; confirmed/completed/cancelled/
-- refunded ones also get the matching lifecycle events. One in five bookings
-- (hash bucket 0) is left without events.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT e.booking_id, e.event_type, e.payload, e.created_at
FROM (
    SELECT
        hb.id AS booking_id,
        ev.step,
        ev.event_type,
        jsonb_build_object(
            'status',   hb.status,
            'amount',   hb.amount,
            'currency', 'INR',
            'channel',  (ARRAY['web', 'mobile', 'agent', 'partner-api'])[1 + mod(abs(hashtext(hb.id::text)), 4)],
            'hotel_id', hb.hotel_id
        ) AS payload,
        hb.created_at + make_interval(mins => ev.step * 7) AS created_at
    FROM hotel_bookings hb
    CROSS JOIN LATERAL (
        VALUES
            (0, 'booking.created',     true),
            (1, 'payment.captured',    hb.status IN ('confirmed', 'completed', 'cancelled', 'refunded')),
            (2, 'booking.confirmed',   hb.status IN ('confirmed', 'completed')),
            (2, 'booking.cancelled',   hb.status IN ('cancelled', 'refunded')),
            (3, 'booking.checked_out', hb.status = 'completed'),
            (3, 'payment.refunded',    hb.status = 'refunded')
    ) AS ev(step, event_type, applies)
    WHERE ev.applies
      AND mod(abs(hashtext('events' || hb.id::text)), 5) <> 0
) AS e
WHERE NOT EXISTS (
    SELECT 1 FROM booking_events be
    WHERE be.booking_id = e.booking_id AND be.event_type = e.event_type
)
ORDER BY e.created_at, e.step;

-- Fresh planner statistics so EXPLAIN reflects the seeded data immediately.
ANALYZE hotel_bookings;
ANALYZE booking_events;
