# Foundation Data Pipeline

A SQL-first pipeline over the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce):
raw CSVs in, a clean relational schema out, queried with SQL alone.

PostgreSQL 18 + pgvector, run in Docker.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/), running
- [Git](https://git-scm.com/). On Windows, run the bash steps below in **Git Bash**
  (installed with Git). In PowerShell, `bash` starts WSL instead, which cannot
  see Docker by default.
- A free [Kaggle](https://www.kaggle.com/) account, to download the dataset
- Python 3 and a free [Cohere](https://dashboard.cohere.com/) API key, *optional*,
  only for the vector search example

## Getting started

### 1. Clone and configure

```bash
git clone https://github.com/alisar-al-musa/sql-exercise.git
cd sql-exercise
cp .env.example .env
```

The defaults in `.env` work as they are. The database is published on host
port **5433**. Change `HOST_PORT` if that port is taken.

### 2. Download the dataset

Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce),
then unzip the nine CSVs into `data/raw/`:

```
data/raw/
├── olist_customers_dataset.csv
├── olist_geolocation_dataset.csv
├── olist_order_items_dataset.csv
├── olist_order_payments_dataset.csv
├── olist_order_reviews_dataset.csv
├── olist_orders_dataset.csv
├── olist_products_dataset.csv
├── olist_sellers_dataset.csv
└── product_category_name_translation.csv
```

`data/raw/` is gitignored because the files total about 123 MB.

### 3. Start the database

```bash
docker compose up -d --wait
```

### 4. Build and load the schema

```bash
bash scripts/seed.sh
```

This applies the migrations, loads the CSVs, cleans them into the `core`
schema and verifies the result. It finishes with `seed complete`, and it
stops with an error if any check fails. You can safely run it again.

### 5. Run a query

```powershell
.\scripts\query.ps1 queries\ex1.sql       # Windows PowerShell
```

```bash
docker compose exec -T db psql -U postgres -d olist < queries/ex1.sql   # any bash shell
```

For an interactive `psql` session:

```bash
docker compose exec db psql -U postgres -d olist
```

### 6. (Optional) Enable vector search

`queries/vector_query.sql` finds the reviews most similar to a given review.
A new database has no embeddings, so this query has nothing to compare and
returns arbitrary rows. To generate embeddings for a 500-review sample, add
your key to `.env` as `COHERE_API_KEY=...`, then run:

```bash
python scripts/embed_reviews.py
```

## Queries

| File | Question |
| --- | --- |
| `ex1.sql` | Joins and filtering |
| `ex2.sql` | Products that have never been ordered |
| `ex3.sql` | Total revenue per month |
| `ex4.sql` | Average review score per category, worst to best |
| `ex5.sql` | Seller revenue rank, overall and within state |
| `ex6.sql` | Running total of each customer's spend |
| `ex7.sql` | Top 3 best-selling products per category |
| `ex8.sql` | First-month customers who did not reorder within 90 days |
| `ex9.sql` | Running total rewritten with a CTE |
| `ex10.sql` | Highest-revenue product category |
| `ex11.sql` | Sellers most at risk of dropping out |
| `ex12.sql` | Share of repeat customers |
| `ex13.sql` | An open-ended question of my own |
| `vector_query.sql` | Nearest-neighbour search over review embeddings |

## Project structure

| Path | Contents |
| --- | --- |
| `migrations/` | Versioned schema, applied in order exactly once |
| `seed/` | Re-runnable load, clean and verify steps |
| `queries/` | One `.sql` file per exercise |
| `scripts/` | Seeder, migration runner, query runner, embedding script |
| `docs/` | ERD and data-profiling notes |
| `data/raw/` | Source CSVs (gitignored) |

## Data model

The data passes through two schemas:

- **`staging`** holds the CSVs exactly as delivered. Every column is `TEXT` and
  there are no constraints, so a bad value can never break the load.
- **`core`** holds the typed, cleaned working schema, with primary keys,
  foreign keys, check constraints and indexes. Every query runs against this
  schema.

Four cleaning rules are applied: one unusable order is dropped, seven missing
delivery dates are imputed, duplicate reviews are reduced to one per order, and
untranslated categories keep their Portuguese name. Each rule was chosen from
measured evidence. The reasoning is in [docs/data-profile.md](docs/data-profile.md).

Things to know when writing queries:

- **`customer_id` is per order, not per person.** Olist issues a new one for
  every order. Use `customer_unique_id` to count people.
- **Use the delivery date to decide whether an order was delivered.** Filter on
  `order_delivered_customer_date IS NOT NULL`. `order_status = 'delivered'` is
  not reliable.
- **Some lookups need a `LEFT JOIN`.** Some products have no category
  translation, and some zip codes have no geolocation, so an inner join drops
  those rows.

The diagram is in [docs/erd.md](docs/erd.md) and [docs/erd.png](docs/erd.png).

## Reset

```bash
docker compose down -v   # deletes the container and all its data
docker compose up -d --wait
bash scripts/seed.sh
```

After a reset, re-run step 6 if you need vector search.

## Troubleshooting

- **`service "db" is not running`**: Docker Desktop is not started, or step 3
  was skipped.
- **Port 5433 already in use**: change `HOST_PORT` in `.env`, then run
  `docker compose up -d` again.
- **Git Bash turns `/data/raw` into a Windows path**: prefix the command with
  `MSYS_NO_PATHCONV=1`, for example
  `MSYS_NO_PATHCONV=1 docker compose exec db ls /data/raw`.
- **Container will not start after editing `docker-compose.yml`**: PostgreSQL 18
  mounts its volume at `/var/lib/postgresql`, not `/var/lib/postgresql/data`.
