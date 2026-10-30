# ADR-0004: Applications read views; privileges are granted by schema role

**Status:** accepted

## Context

When services and map layers query tables directly, every physical change — a
rename, a split, a new join — becomes a coordinated multi-team deploy. And when
each app gets its own ad-hoc grants, nobody can answer "who can write to
production?" without an archaeology session.

## Decision

- The `app` schema holds views that are the **only** surface applications touch.
  ArcGIS query layers, dashboards, and services all point at `app.*`.
- Three `NOLOGIN` group roles own all privileges: `gis_reader` (SELECT on `app`),
  `gis_etl` (write `ops`, read `ref`), `gis_admin` (DDL). Humans and service
  accounts get membership, never direct grants. `ALTER DEFAULT PRIVILEGES` keeps
  future tables covered automatically.

## Consequences

The physical model can evolve behind stable view contracts; the facility table
split in migration review required zero client changes. Access audit is one query
over three roles. Cost: views need maintaining alongside schema changes — enforced
by keeping both in the same migration (see 0003).
