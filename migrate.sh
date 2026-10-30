#!/usr/bin/env bash
# Minimal, dependency-free migration runner: ordered SQL files + a ledger table.
# Each migration runs in its own transaction (the files BEGIN/COMMIT themselves);
# the ledger insert rides in a wrapper transaction so a crash never records
# a migration that didn't finish.
#
#   DATABASE_URL=postgres://user:pw@host/db ./migrate.sh [--dry-run]
set -euo pipefail

DATABASE_URL="${DATABASE_URL:?set DATABASE_URL (postgres://user:pw@host/db)}"
DRY_RUN="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"

psql_q() { psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -qAt "$@"; }

psql_q -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);"

applied="$(psql_q -c 'SELECT version FROM public.schema_migrations')"

for file in "$HERE"/migrations/*.sql; do
    version="$(basename "$file" .sql)"
    if grep -qx "$version" <<<"$applied"; then
        echo "skip   $version"
        continue
    fi
    if [[ "$DRY_RUN" == "--dry-run" ]]; then
        echo "would  $version"
        continue
    fi
    echo "apply  $version"
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$file"
    psql_q -c "INSERT INTO public.schema_migrations (version) VALUES ('$version')"
done

echo "done"
