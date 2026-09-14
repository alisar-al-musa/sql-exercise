#!/usr/bin/env bash
# Apply every migration in /migrations, in filename order, exactly once.
#
# Idempotent: already-applied migrations are skipped, so this is safe to re-run.
# Each migration runs in a single transaction -- if it fails, nothing is applied
# and it is not recorded, so you can fix the file and run again.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

PSQL="docker compose exec -T -e PGPASSWORD=$POSTGRES_PASSWORD db psql -v ON_ERROR_STOP=1 -U $POSTGRES_USER -d $POSTGRES_DB"

# Ledger of what has already run.
$PSQL -q -c "CREATE TABLE IF NOT EXISTS schema_migrations (
  version     TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);"

applied=0
for f in migrations/*.sql; do
  version="$(basename "$f")"
  exists="$($PSQL -tAc "SELECT 1 FROM schema_migrations WHERE version = '$version';")"
  if [ -n "$exists" ]; then
    echo "  skip    $version (already applied)"
    continue
  fi
  echo "  apply   $version"
  # BEGIN/COMMIT wrap the file so a partial failure rolls back cleanly.
  { echo "BEGIN;"; cat "$f"; \
    echo "INSERT INTO schema_migrations (version) VALUES ('$version');"; \
    echo "COMMIT;"; } | $PSQL -q
  applied=$((applied + 1))
done

echo "migrations complete ($applied applied)"
