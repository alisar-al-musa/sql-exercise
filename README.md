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
never duplicates rows. `seed/02_verify_staging.sql` then compares every table
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

### Cleaning

`core.*` is the working schema: real types, corrected names, cleaning rules
applied. The pipeline runs in four steps, each verified before the next
consumes it.

| Step | File | Does |
| --- | --- | --- |
| 1 | `seed/01_load_staging.sql` | CSVs into `staging.*`, all TEXT |
| 2 | `seed/02_verify_staging.sql` | row counts match the source files |
| 3 | `seed/03_clean.sql` | `staging.*` cast and cleaned into `core.*` |
| 4 | `seed/04_verify_core.sql` | counts, key uniqueness, cleaning rules, FK integrity |

Four cleaning rules are applied, each decided from measured evidence rather
than assumption. The full reasoning, including the options rejected, is in
[docs/data-profile.md](docs/data-profile.md).

1. **One order dropped.** It is marked `delivered` with neither a delivery nor
   a carrier date, so nothing supports an estimate. Its `order_items`, payment
   and review rows go with it, or they would point at a missing order.
2. **Seven delivery dates imputed** as `carrier_date + 7.1 days`, the measured
   median handover-to-customer gap. The carrier date alone is a lower bound and
   would assert a zero-day delivery.
3. **`order_reviews` de-duplicated to one review per order**, keeping the
   latest `review_answer_timestamp`. 202 of the 547 duplicated orders disagree
   on score, so the tie-break is not cosmetic.
4. **Category translated with a fallback.** A `LEFT JOIN` plus `COALESCE`, so
   the 13 products in categories missing from the translation file keep their
   Portuguese name instead of being dropped.

The remaining 2,957 missing delivery dates stay `NULL` -- those orders were
never delivered, so no date exists. Queries about delivery must filter on
`order_delivered_customer_date IS NOT NULL` rather than trusting
`order_status = 'delivered'`.

Primary keys, foreign keys and indexes are **not** applied here; they arrive in
migration 004. `seed/04_verify_core.sql` proves every intended key is already
unique and every planned foreign key would hold, so 004 declares them knowing
they cannot fail.

## Schema

`migrations/004_keys_and_indexes.sql` turns the working schema into a real
relational model, and `005_review_embeddings.sql` adds the vector column. The
diagram is in [docs/erd.md](docs/erd.md).

| | Count | Notes |
| --- | ---: | --- |
| Primary keys | 8 | 3 composite; `geolocation` deliberately has none |
| Unique constraints | 1 | `orders.customer_id` — this is what makes it 1:1 |
| Foreign keys | 6 | `ON DELETE NO ACTION`, not `CASCADE` |
| Check constraints | 10 | each counted against the data before declaring |
| Indexes | 6 | beyond the 9 that keys create automatically |

Three points a reviewer usually asks about:

**`orders` → `customers` is 1:1.** Olist issues a fresh `customer_id` for every
order, so `customers` is an order-address snapshot rather than a table of
people. The `UNIQUE` constraint states this rather than letting the diagram
imply a many-to-1 that does not exist. The person is `customer_unique_id`
(96,096 distinct, indexed) — so `count(DISTINCT customer_id)` counts **orders**.

**Three expected foreign keys are absent**, because the data refuses them:
`products → translation` (13 orphan products), and both zip-code columns
→ `geolocation` (157 and 7 orphan prefixes). All three are `LEFT JOIN` lookups.

**Four obvious-looking check constraints were tested and rejected** — delivery
dates preceding handover (23 rows), carrier dates preceding purchase (166),
zero product weights (4), coordinates outside Brazil (33). Declaring any would
mean deleting 193 real rows to satisfy a rule we invented. Section 8 of
[docs/data-profile.md](docs/data-profile.md) has the full list, declared and
rejected.

The `embedding vector(1024)` column on `order_reviews` is nullable and left
empty; populating it needs an embedding model, which is outside this pipeline.
No vector index is built — an `ivfflat` index clusters the rows present when it
is created, so building one on an empty table produces an index that degrades
to a sequential scan.

## Running a query file

```bash
bash scripts/query.sh queries/5_1.sql        # Git Bash
```

```powershell
.\scripts\query.ps1 queries\5_1.sql          # PowerShell
```

Both pipe the file over stdin, because `queries/` is not mounted into the
container. Use the PowerShell version from a normal Windows terminal: there,
`bash` resolves to WSL's bash, which cannot see Docker unless WSL integration
is enabled in Docker Desktop.

For an interactive session:

```bash
docker compose exec db psql -U postgres -d olist
```

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
