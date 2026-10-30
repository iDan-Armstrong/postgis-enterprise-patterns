-- 0003: ops.facility — the core operational table
--
-- Patterns on display:
--   * natural key kept UNIQUE, surrogate identity PK for joins
--   * CHECK constraints encode the data contract in the database itself —
--     the last line of defense when some future loader skips the ETL's QA
--   * district_id is a real FK: facts the database can enforce, it should
--   * updated_at maintained by trigger, not by trusting every writer

BEGIN;

CREATE TABLE ops.facility (
    facility_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id       text NOT NULL UNIQUE,
    name            text NOT NULL CHECK (length(trim(name)) >= 3),
    facility_type   text NOT NULL CHECK (
                        facility_type IN ('clinic', 'hospital', 'health_post', 'pharmacy')
                    ),
    beds            integer CHECK (beds BETWEEN 0 AND 5000),
    district_id     integer REFERENCES ref.district (district_id),
    geom            geometry(Point, 4326) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT facility_geom_valid CHECK (ST_IsValid(geom)),
    -- reject null island and friends: a 0,0 point is a bug, not a place
    CONSTRAINT facility_not_null_island CHECK (NOT ST_Equals(geom, ST_Point(0, 0, 4326)))
);

CREATE INDEX facility_geom_gix ON ops.facility USING gist (geom);
CREATE INDEX facility_district_ix ON ops.facility (district_id);
CREATE INDEX facility_type_ix ON ops.facility (facility_type);

-- clock_timestamp(), not now(): now() is frozen for the whole transaction,
-- so a long-running ETL batch would stamp every row with its start time —
-- and the trigger would be untestable inside a single transaction.
CREATE OR REPLACE FUNCTION ops.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$$;

CREATE TRIGGER facility_touch
    BEFORE UPDATE ON ops.facility
    FOR EACH ROW EXECUTE FUNCTION ops.touch_updated_at();

-- the only thing applications see (ADR-0004): physical changes stay invisible
CREATE VIEW app.facility AS
SELECT
    f.facility_id,
    f.source_id,
    f.name,
    f.facility_type,
    f.beds,
    d.name AS district_name,
    f.geom,
    f.updated_at
FROM ops.facility AS f
LEFT JOIN ref.district AS d USING (district_id);

COMMENT ON VIEW app.facility IS 'Application-facing facility view; stable contract';

COMMIT;
