-- 0002: reference layer — administrative districts
--
-- SRID strategy (ADR-0002): storage is EPSG:4326 everywhere; analysis
-- reprojects explicitly. One SRID in storage means spatial joins never hit
-- the "mixed SRID" error at 2 a.m., and 4326 round-trips cleanly through
-- GeoJSON, AGOL, and every client.

BEGIN;

CREATE TABLE ref.district (
    district_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text NOT NULL UNIQUE,
    iso_code      text,
    geom          geometry(MultiPolygon, 4326) NOT NULL,
    -- generated planar area in km² (equal-area projection, not degrees²)
    area_sqkm     double precision GENERATED ALWAYS AS (
                      ST_Area(ST_Transform(geom, 6933)) / 1000000.0
                  ) STORED,
    CONSTRAINT district_geom_valid CHECK (ST_IsValid(geom))
);

CREATE INDEX district_geom_gix ON ref.district USING gist (geom);

COMMENT ON TABLE ref.district IS 'Administrative districts (authoritative boundary set)';
COMMENT ON COLUMN ref.district.area_sqkm IS 'Generated: equal-area (EPSG:6933) km²';

COMMIT;
