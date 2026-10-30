-- Spatial index benchmark: measure what the GIST index actually buys.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -v n=1000000 -f benchmark/spatial_index_benchmark.sql
--
-- Generates :n random points, times a radius query (ST_DWithin on geography)
-- and a bbox+polygon query (ST_Intersects) with and without the index, and
-- prints a results table. Everything happens in a scratch schema that is
-- dropped at the end.

\set n :n
\if :{?n}
\else
\set n 1000000
\endif

CREATE SCHEMA IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.pt;
CREATE TABLE bench.pt AS
SELECT
    n AS id,
    ST_Point(-77.6 + random() * 0.8, 4.0 + random() * 0.8, 4326)::geometry(Point, 4326) AS geom
FROM generate_series(1, :n) AS n;

VACUUM ANALYZE bench.pt;

CREATE TABLE IF NOT EXISTS bench.result (
    label text,
    with_index boolean,
    ms double precision
);
TRUNCATE bench.result;

CREATE OR REPLACE FUNCTION bench.time_query(label text, with_index boolean, sql text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    t0 timestamptz;
    elapsed_ms double precision;
    i integer;
BEGIN
    -- warm cache once, then take the best of three (steady-state cost)
    EXECUTE sql;
    elapsed_ms := 'infinity';
    FOR i IN 1..3 LOOP
        t0 := clock_timestamp();
        EXECUTE sql;
        elapsed_ms := least(elapsed_ms,
                            extract(epoch FROM clock_timestamp() - t0) * 1000);
    END LOOP;
    INSERT INTO bench.result VALUES (label, with_index, elapsed_ms);
END;
$$;

-- the two queries every GIS backend serves all day
\set radius_q 'SELECT count(*) FROM bench.pt WHERE ST_DWithin(geom::geography, ST_Point(-77.2, 4.4, 4326)::geography, 5000)'
\set bbox_q   'SELECT count(*) FROM bench.pt WHERE ST_Intersects(geom, ST_MakeEnvelope(-77.3, 4.3, -77.1, 4.5, 4326))'

-- without index
SET max_parallel_workers_per_gather = 0;  -- measure the plan, not the core count
SELECT bench.time_query('radius 5km', false, :'radius_q');
SELECT bench.time_query('bbox 0.2deg', false, :'bbox_q');

-- with index
CREATE INDEX pt_geom_gix ON bench.pt USING gist (geom);
CREATE INDEX pt_geog_gix ON bench.pt USING gist ((geom::geography));
VACUUM ANALYZE bench.pt;

SELECT bench.time_query('radius 5km', true, :'radius_q');
SELECT bench.time_query('bbox 0.2deg', true, :'bbox_q');

-- report
SELECT
    label,
    round(max(ms) FILTER (WHERE NOT with_index)::numeric, 1) AS seq_scan_ms,
    round(max(ms) FILTER (WHERE with_index)::numeric, 1) AS index_ms,
    round((max(ms) FILTER (WHERE NOT with_index)
         / nullif(max(ms) FILTER (WHERE with_index), 0))::numeric, 0) AS speedup
FROM bench.result
GROUP BY label
ORDER BY label;

DROP SCHEMA bench CASCADE;
