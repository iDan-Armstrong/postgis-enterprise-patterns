-- 0005: roles and grants — least privilege, by schema
--
-- Three NOLOGIN group roles; humans and service accounts are granted
-- membership. No application ever connects as the owner.
--   gis_reader: SELECT on app views only (ArcGIS query layers, dashboards)
--   gis_etl:    writes ops + ref, cannot touch app definitions
--   gis_admin:  DDL (migrations run as this)

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gis_reader') THEN
        CREATE ROLE gis_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gis_etl') THEN
        CREATE ROLE gis_etl NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gis_admin') THEN
        CREATE ROLE gis_admin NOLOGIN;
    END IF;
END
$$;

-- readers: app views only — not ops, not ref
GRANT USAGE ON SCHEMA app TO gis_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO gis_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO gis_reader;

-- etl: read reference, write operational
GRANT USAGE ON SCHEMA ref, ops TO gis_etl;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO gis_etl;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ops TO gis_etl;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ops TO gis_etl;
ALTER DEFAULT PRIVILEGES IN SCHEMA ops
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gis_etl;
ALTER DEFAULT PRIVILEGES IN SCHEMA ops GRANT USAGE ON SEQUENCES TO gis_etl;

-- admin: everything on all three schemas
GRANT ALL ON SCHEMA ref, ops, app TO gis_admin;
GRANT ALL ON ALL TABLES IN SCHEMA ref, ops, app TO gis_admin;

COMMIT;
