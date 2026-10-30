-- 0001: extensions and schema layout
--
-- Schemas separate concerns and make grants coarse and auditable:
--   ref: slowly-changing reference data (boundaries, lookups) — read-mostly
--   ops: operational data the ETL writes — the working heart
--   app: views exposed to services and ArcGIS; apps NEVER read tables directly,
--        so the physical model can change without breaking a single client.

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS app;

COMMENT ON SCHEMA ref IS 'Reference data: boundaries, lookup tables (read-mostly)';
COMMENT ON SCHEMA ops IS 'Operational data: ETL-managed tables';
COMMENT ON SCHEMA app IS 'Stable views for applications; no direct table access';

COMMIT;
