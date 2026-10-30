-- Smoke test: the migrated database must actually behave as designed.
-- Run after migrate.sh:  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/smoke.sql
-- Every check raises on failure, so CI fails loudly.

BEGIN;

-- seed a district and facilities
INSERT INTO ref.district (name, iso_code, geom) VALUES
('Northwood', 'NW',
 ST_Multi(ST_GeomFromText('POLYGON((-77.6 4.4, -77.2 4.4, -77.2 4.8, -77.6 4.8, -77.6 4.4))', 4326)));

INSERT INTO ops.facility (source_id, name, facility_type, beds, district_id, geom)
SELECT 'SRC-' || n, 'Facility ' || n, 'clinic', 10,
       (SELECT district_id FROM ref.district WHERE name = 'Northwood'),
       ST_Point(-77.4 + n * 0.001, 4.6, 4326)
FROM generate_series(1, 5) AS n;

-- 1) generated area column is sane (the district is roughly 44km x 44km)
DO $$
DECLARE a double precision;
BEGIN
    SELECT area_sqkm INTO a FROM ref.district WHERE name = 'Northwood';
    IF a NOT BETWEEN 1500 AND 2500 THEN
        RAISE EXCEPTION 'generated area_sqkm suspicious: %', a;
    END IF;
END $$;

-- 2) constraints reject bad data
DO $$
BEGIN
    BEGIN
        INSERT INTO ops.facility (source_id, name, facility_type, geom)
        VALUES ('BAD-1', 'Null Island Clinic', 'clinic', ST_Point(0, 0, 4326));
        RAISE EXCEPTION 'null island insert should have failed';
    EXCEPTION WHEN check_violation THEN NULL; -- expected
    END;
    BEGIN
        INSERT INTO ops.facility (source_id, name, facility_type, geom)
        VALUES ('BAD-2', 'Spaceport', 'spaceport', ST_Point(-77.4, 4.6, 4326));
        RAISE EXCEPTION 'bad facility_type should have failed';
    EXCEPTION WHEN check_violation THEN NULL; -- expected
    END;
END $$;

-- 3) updated_at trigger fires
DO $$
DECLARE before_ts timestamptz; after_ts timestamptz;
BEGIN
    SELECT updated_at INTO before_ts FROM ops.facility WHERE source_id = 'SRC-1';
    PERFORM pg_sleep(0.01);
    UPDATE ops.facility SET beds = 11 WHERE source_id = 'SRC-1';
    SELECT updated_at INTO after_ts FROM ops.facility WHERE source_id = 'SRC-1';
    IF after_ts <= before_ts THEN
        RAISE EXCEPTION 'updated_at trigger did not fire';
    END IF;
END $$;

-- 4) app view joins district name
DO $$
DECLARE d text;
BEGIN
    SELECT district_name INTO d FROM app.facility WHERE source_id = 'SRC-1';
    IF d IS DISTINCT FROM 'Northwood' THEN
        RAISE EXCEPTION 'app.facility district join broken: %', d;
    END IF;
END $$;

-- 5) observation partitions route rows and reject out-of-range dates
SELECT ops.ensure_observation_partitions(current_date, 1);
INSERT INTO ops.observation (facility_id, observed_at, metric, value, geom)
SELECT facility_id, now(), 'patients_seen', 12, geom
FROM ops.facility WHERE source_id = 'SRC-1';

DO $$
BEGIN
    BEGIN
        INSERT INTO ops.observation (facility_id, observed_at, metric, value)
        SELECT facility_id, timestamptz '1999-01-01', 'patients_seen', 1
        FROM ops.facility WHERE source_id = 'SRC-1';
        RAISE EXCEPTION 'insert outside partition range should have failed';
    EXCEPTION WHEN check_violation THEN NULL; -- no partition for 1999
    END;
END $$;

ROLLBACK;  -- smoke data never persists

SELECT 'smoke: OK' AS result;
