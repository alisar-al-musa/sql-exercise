#!/usr/bin/env bash
# Profile the staging data. Read-only -- changes nothing.
# Produces the evidence recorded in docs/data-profile.md.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

# Piped over stdin because scripts/ is not mounted into the container.
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" db \
  psql -v ON_ERROR_STOP=1 -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  < scripts/profile.sql
