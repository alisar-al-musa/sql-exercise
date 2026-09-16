#!/usr/bin/env bash
# Run a .sql file against the database and print the result.
#
#   bash scripts/query.sh queries/ex1.sql
#   bash scripts/query.sh queries/ex1.sql > out.txt    # capture the result
#
# Piped over stdin because queries/ is not mounted into the container, and
# because Git Bash rewrites container paths given on the command line.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a; source .env; set +a

f="${1:-}"
if [ -z "$f" ]; then
  echo "usage: bash scripts/query.sh <file.sql>" >&2
  exit 2
fi
if [ ! -f "$f" ]; then
  echo "no such file: $f" >&2
  exit 2
fi

# \timing is a psql meta-command, not a command-line flag, so it is prepended
# to the stream rather than passed as an option. It reports how long each
# statement took.
#
# ON_ERROR_STOP makes psql stop at the first error rather than continuing.
{ echo '\timing on'; cat "$f"; } \
  | docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" db \
      psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"
