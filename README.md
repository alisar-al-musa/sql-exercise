# Foundation Data Pipeline

A SQL-first pipeline over the Olist Brazilian e-commerce dataset: raw CSVs in,
a clean relational schema out, queried with SQL alone.

## Requirements

- Docker Desktop
- Git Bash (Windows) or any POSIX shell

## Stand up from zero

```bash
# 1. Configuration
cp .env.example .env

# 2. Fetch the dataset (see "Dataset" below) into data/raw/

# 3. Start PostgreSQL 18 + pgvector
docker compose up -d

# 4. Migrate and seed -- raw CSVs to a fully seeded database
bash scripts/seed.sh
```

Connect with:

```bash
docker compose exec db psql -U postgres -d olist
```

## Dataset

Nine CSVs from the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
Download from Kaggle (free account required) and unzip into `data/raw/`.

`data/raw/` is gitignored — roughly 123 MB, too large for the repo.

Expected contents once in place:

| File | Rows |
| --- | ---: |
| olist_customers_dataset.csv | 99,441 |
| olist_geolocation_dataset.csv | 1,000,163 |
| olist_order_items_dataset.csv | 112,650 |
| olist_order_payments_dataset.csv | 103,886 |
| olist_order_reviews_dataset.csv | 99,224 |
| olist_orders_dataset.csv | 99,441 |
| olist_products_dataset.csv | 32,951 |
| olist_sellers_dataset.csv | 3,095 |
| product_category_name_translation.csv | 71 |

## Layout

| Path | Contents |
| --- | --- |
| `migrations/` | Schema as versioned SQL. Never edit the database by hand. |
| `seed/` | Re-runnable ingestion scripts. |
| `queries/` | One `.sql` per exercise, named by exercise number. |
| `docs/` | ERD and supporting notes. |
| `scripts/` | Operational scripts (migration runner, seeder). |
| `data/raw/` | Source CSVs (gitignored). |

## Migrations

`scripts/migrate.sh` applies every file in `migrations/` in filename order,
exactly once, recording each in a `schema_migrations` table. Re-running is safe:
applied migrations are skipped. Each migration runs in one transaction, so a
failure rolls back fully and is not recorded.

To add one, create `migrations/00N_description.sql` and re-run the script.

## Seeding

`scripts/seed.sh` is the single command from raw CSVs to a seeded database. It
applies pending migrations, then runs every file in `seed/` in filename order.

It is idempotent -- each load truncates its tables before copying, so re-running
never duplicates rows. `seed/99_verify_staging.sql` then compares every table
against the source row counts and fails loudly if any differ.

Loading uses server-side `COPY` reading from the read-only `/data/raw` mount,
rather than `\copy`, which would stream all 1,000,163 geolocation rows through
the client. A full load takes about 10 seconds.

### Staging

`staging.*` is a landing zone that mirrors the CSVs exactly: every column
`TEXT`, header names copied verbatim (including the dataset's own misspelling
`product_name_lenght`), and no keys or constraints. A bad value can therefore
never abort a load, and duplicates and nulls stay visible as findings rather
than becoming errors. Typing and cleaning happen in a later, separate step.

`product_category_name_translation.csv` begins with a UTF-8 BOM. `HEADER true`
discards the first line without parsing it, so the BOM is never read. Do not
switch to `HEADER MATCH` -- it validates header names and would fail on it.

## Local notes

**Port 5433, not 5432.** Another project on this machine already uses 5432, so
the host port is 5433 (`HOST_PORT` in `.env`). Inside the container it is still
5432. From the host: `psql -h localhost -p 5433 -U postgres -d olist`.

**Git Bash mangles container paths.** Git Bash rewrites `/data/raw` into a
Windows path before Docker sees it. Prefix commands containing container paths
with `MSYS_NO_PATHCONV=1`:

```bash
MSYS_NO_PATHCONV=1 docker compose exec db ls /data/raw
```

**PostgreSQL 18 changed the data volume path.** The volume mounts at
`/var/lib/postgresql`, not `/var/lib/postgresql/data` as in PG 17 and earlier.
Using the old path makes the container refuse to start.

## Reset

```bash
docker compose down -v   # deletes the volume and all data
docker compose up -d
bash scripts/seed.sh
```
