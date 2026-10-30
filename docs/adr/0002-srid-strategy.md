# ADR-0002: One storage SRID (EPSG:4326); project explicitly for math

**Status:** accepted

## Context

Spatial data arrives in whatever CRS each source uses. Teams that store mixed SRIDs
meet the `ST_Intersects: Operation on mixed SRID geometries` error in production,
usually at night. Teams that store a local projected CRS get fast planar math but
painful web/AGOL interop and a problem the day the project crosses the zone boundary.

## Decision

- Every stored geometry column is typed `geometry(<Type>, 4326)` — the type modifier
  makes the database reject wrong-SRID writes instead of trusting every loader.
- Distance/area math goes through `::geography` (meters, correct everywhere) or an
  explicit `ST_Transform` to an equal-area CRS (6933) for bulk analysis, chosen per
  query and visible in the SQL.
- Generated columns bake the projection in where it's hot (e.g. `area_sqkm` on
  `ref.district`), so app queries never recompute it.

## Consequences

Interop with GeoJSON, ArcGIS Online, and web clients is zero-friction; no client ever
re-projects to display. The cost — remembering `::geography` for metric math — is
mitigated by the geography functional index (see benchmark) and code review. For a
future single-country deployment where all analysis is planar, a projected storage
CRS would be a reasonable successor ADR.
