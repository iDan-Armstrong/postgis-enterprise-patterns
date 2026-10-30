-- 0004: ops.observation — high-volume time series, range-partitioned by month
--
-- Why partitioning (ADR-0003): observation-style tables grow without bound,
-- and the access pattern is overwhelmingly "recent window + spatial filter".
-- Monthly range partitions keep indexes small and hot, make retention a
-- DETACH/DROP instead of a multi-hour DELETE, and let autovacuum keep up.
-- Partitions are pre-created by the helper below (call it from the ETL or
-- a scheduled job; creating partitions at insert time is a lock festival).

BEGIN;

CREATE TABLE ops.observation (
    observation_id  bigint GENERATED ALWAYS AS IDENTITY,
    facility_id     bigint NOT NULL REFERENCES ops.facility (facility_id),
    observed_at     timestamptz NOT NULL,
    metric          text NOT NULL,
    value           double precision NOT NULL,
    geom            geometry(Point, 4326),
    PRIMARY KEY (observation_id, observed_at)
) PARTITION BY RANGE (observed_at);

-- partition-management helper: idempotent, creates month partitions + indexes
CREATE OR REPLACE FUNCTION ops.ensure_observation_partitions(
    from_month date,
    months integer
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    month_start date;
    part_name text;
BEGIN
    FOR i IN 0 .. months - 1 LOOP
        month_start := date_trunc('month', from_month) + make_interval(months => i);
        part_name := format('observation_%s', to_char(month_start, 'YYYY_MM'));
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS ops.%I PARTITION OF ops.observation
             FOR VALUES FROM (%L) TO (%L)',
            part_name, month_start, month_start + interval '1 month'
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON ops.%I USING gist (geom)',
            part_name || '_geom_gix', part_name
        );
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON ops.%I (facility_id, observed_at)',
            part_name || '_fac_ts_ix', part_name
        );
    END LOOP;
END;
$$;

-- bootstrap: this month and the next two
SELECT ops.ensure_observation_partitions(current_date, 3);

COMMIT;
