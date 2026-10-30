# ADR-0003: Range-partition the observation table by month

**Status:** accepted

## Context

`ops.observation` is append-only telemetry: unbounded growth, and ~95% of queries
touch a recent time window plus a spatial filter. At enterprise volumes a single
table means ever-growing indexes, multi-hour `DELETE`s for retention, and autovacuum
falling behind.

## Decision

Native range partitioning on `observed_at`, one partition per month, each with its
own GIST and `(facility_id, observed_at)` indexes. Partitions are pre-created by
`ops.ensure_observation_partitions()` — idempotent, called by the ETL/scheduler —
because creating partitions lazily at insert time serializes writers on a lock.
Retention is `DETACH PARTITION` then drop/archive: seconds, not hours.

## Consequences

Time-windowed queries prune to 1–2 partitions and their small, hot indexes. The
primary key must include the partition key (`(observation_id, observed_at)`) — a
PostgreSQL constraint worth knowing before, not after. Cross-month queries fan out;
acceptable for the 5% case. If the write rate grows another order of magnitude,
sub-partitioning by facility region is the escape hatch.
