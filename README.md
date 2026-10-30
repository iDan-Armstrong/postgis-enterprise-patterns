# postgis-enterprise-patterns — spatial database architecture, executable

![CI](https://github.com/iDan-Armstrong/postgis-enterprise-patterns/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-green)

A reference implementation of the database architecture decisions behind an enterprise
GIS backend — as **running, CI-verified code**, not a diagram. Every migration applies
against a real PostGIS in CI, a smoke test proves the constraints/triggers/views/partitions
behave, and the index benchmark produces numbers, not adjectives.

## What's here

```
migrations/     numbered SQL: schemas, reference + operational tables, partitioning, roles
migrate.sh      dependency-free runner (ledger table, idempotent, --dry-run)
tests/smoke.sql behavioral test of the migrated database (runs in CI, rolls back)
benchmark/      spatial index benchmark (seq scan vs GIST, radius + bbox)
docs/adr/       the "why" — four architecture decision records
terraform/rds   the "where" — PostgreSQL on RDS, validated in CI
docker-compose.yml  local PostGIS in one command
```

## The decisions (each one an ADR)

| ADR | Decision | One-line why |
|---|---|---|
| [0002](docs/adr/0002-srid-strategy.md) | Store everything `geometry(T, 4326)`; project explicitly for math | typmod rejects wrong-SRID writes; zero-friction web/AGOL interop |
| [0003](docs/adr/0003-partition-observations.md) | Month-range partitions for telemetry, pre-created by a helper function | small hot indexes; retention = detach, not a 6-hour DELETE |
| [0004](docs/adr/0004-apps-read-views-roles-by-schema.md) | Apps read `app.*` views only; three NOLOGIN roles own all grants | physical model evolves without client deploys; auditable access |

Patterns inside the migrations worth a look: CHECK constraints as the data contract's
last line of defense (including a null-island rejection), generated equal-area `area_sqkm`,
`clock_timestamp()` (not transaction-frozen `now()`) in the audit trigger, and
`ALTER DEFAULT PRIVILEGES` so future tables inherit the grant model.

## Benchmark: what the GIST index buys

1,000,000 random points, best of 3 after warm-up, parallelism off (PostgreSQL 16 / PostGIS 3.4):

| query | seq scan | GIST index | speedup |
|---|---:|---:|---:|
| 5 km radius (`ST_DWithin` on geography) | 1465 ms | 23 ms | **64×** |
| bbox + `ST_Intersects` (0.2°) | 236 ms | 73 ms | 3× |

The bbox case is modest because the result set itself is large — the honest lesson is
that the index removes the *search*, not the *fetch*. Reproduce it:

```bash
docker compose up -d
export DATABASE_URL=postgres://gis:gis@localhost:5432/gisdb
./migrate.sh
psql "$DATABASE_URL" -v n=1000000 -f benchmark/spatial_index_benchmark.sql
```

## CI proves it

Every push: migrations apply to a fresh `postgis/postgis:16-3.4` → a second run must be
all skips (idempotency) → `tests/smoke.sql` exercises constraints, the audit trigger,
the app view join, and partition routing → the benchmark runs at 100k points →
`terraform validate` checks the RDS module.

## License

MIT
