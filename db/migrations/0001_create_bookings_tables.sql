-- 0001: core booking tables.
--
-- Column types follow the suggested schema. Extra CHECK constraints keep the
-- data clean enough to query and index reliably:
--   * city is stored lower-case, so `WHERE city = 'delhi'` matches every Delhi row
--     and stays a plain equality predicate the B-tree index can use.
--   * status is restricted to the known lifecycle values.

CREATE TABLE hotel_bookings (
    id            UUID          PRIMARY KEY,
    org_id        UUID          NOT NULL,
    hotel_id      VARCHAR(100)  NOT NULL,
    city          VARCHAR(100)  NOT NULL,
    checkin_date  DATE          NOT NULL,
    checkout_date DATE          NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    status        VARCHAR(50)   NOT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT now(),

    CONSTRAINT hotel_bookings_city_lowercase_chk CHECK (city = lower(btrim(city))),
    CONSTRAINT hotel_bookings_dates_chk          CHECK (checkout_date > checkin_date),
    CONSTRAINT hotel_bookings_amount_chk         CHECK (amount >= 0),
    CONSTRAINT hotel_bookings_status_chk         CHECK (status IN (
        'pending', 'confirmed', 'completed', 'cancelled', 'refunded'
    ))
);

COMMENT ON TABLE  hotel_bookings            IS 'One row per hotel booking.';
COMMENT ON COLUMN hotel_bookings.city       IS 'Normalised lower-case city name, e.g. delhi.';
COMMENT ON COLUMN hotel_bookings.created_at IS 'UTC timestamp the booking was created.';

CREATE TABLE booking_events (
    id         BIGSERIAL    PRIMARY KEY,
    booking_id UUID         NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload    JSONB,
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);

COMMENT ON TABLE booking_events IS 'Append-only audit/event log per booking.';

-- PostgreSQL does not index foreign keys automatically. This one serves
-- "events for booking X in order" and keeps ON DELETE CASCADE from scanning
-- the whole events table.
CREATE INDEX idx_booking_events_booking_id_created_at
    ON booking_events (booking_id, created_at);
