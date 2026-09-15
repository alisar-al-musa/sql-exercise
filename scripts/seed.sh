#!/usr/bin/env bash
# Single command: raw CSVs -> fully seeded database.
#
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
  # ON_ERROR_STOP makes psql abort on the first error instead of ploughing on.
  docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" db \
    psql -v ON_ERROR_STOP=1 -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -f "/seed/$(basename "$f")"
done

echo "seed complete"
