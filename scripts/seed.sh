#!/usr/bin/env bash
# Single command: raw CSVs -> fully seeded database.
# bash scripts/seed.sh

# Applies any pending migrations, then runs every seed script in /seed in
# filename order. Safe to re-run: migrations are skipped once applied, and
# each load truncates before copying, so counts never double.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

echo "== migrations"
bash scripts/migrate.sh

echo "== seeding"
for f in seed/*.sql; do
  echo "  run     $(basename "$f")"
  # Piped over stdin rather than `psql -f /seed/...`, for the same reason
  # migrate.sh pipes: Git Bash rewrites a leading /seed/... into a Windows path
  # before Docker ever sees it, and psql then looks for the file on the host.
  # Piping also removes the dependency on /seed being mounted at all.
  #
  # The /data/raw/... paths inside 01_load_staging.sql are unaffected -- they
  # live in the SQL text and are resolved by the server, not by the shell.
  #
  # ON_ERROR_STOP makes psql abort on the first error instead of ploughing on.
  docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" db \
    psql -v ON_ERROR_STOP=1 -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$f"
done

echo "seed complete"
