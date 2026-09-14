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

# 4. Apply the schema
bash scripts/migrate.sh
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
| `scripts/` | Operational scripts (migration runner). |
| `data/raw/` | Source CSVs (gitignored). |

## Migrations

`scripts/migrate.sh` applies every file in `migrations/` in filename order,
exactly once, recording each in a `schema_migrations` table. Re-running is safe:
applied migrations are skipped. Each migration runs in one transaction, so a
failure rolls back fully and is not recorded.

To add one, create `migrations/00N_description.sql` and re-run the script.

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
bash scripts/migrate.sh
```
