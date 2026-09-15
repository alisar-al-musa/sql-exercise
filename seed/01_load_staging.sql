-- Load the raw CSVs into the staging schema.
--
-- Idempotent: every table is truncated first, so re-running this produces
-- identical row counts rather than duplicating data.
--
-- Uses server-side COPY (not \copy). The server reads straight off the
-- read-only bind mount at /data/raw declared in docker-compose.yml, instead
-- of streaming every row through the client connection -- a large difference
-- on the 1,000,163-row geolocation file.
--
-- HEADER true makes COPY discard the first line without parsing it. That is
-- also what neutralises the UTF-8 BOM on product_category_name_translation.csv:
-- the BOM bytes sit on the header line and are never read. (Do NOT switch to
-- HEADER MATCH -- that validates header names and would fail on the BOM.)
-- CSV mode handles the CRLF line endings on its own.

BEGIN;

TRUNCATE
  staging.customers,
  staging.geolocation,
  staging.orders,
  staging.order_items,
  staging.order_payments,
  staging.order_reviews,
  staging.products,
  staging.sellers,
  staging.product_category_name_translation;

COPY staging.customers
  FROM '/data/raw/olist_customers_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.geolocation
  FROM '/data/raw/olist_geolocation_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.orders
  FROM '/data/raw/olist_orders_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.order_items
  FROM '/data/raw/olist_order_items_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.order_payments
  FROM '/data/raw/olist_order_payments_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.order_reviews
  FROM '/data/raw/olist_order_reviews_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.products
  FROM '/data/raw/olist_products_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.sellers
  FROM '/data/raw/olist_sellers_dataset.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging.product_category_name_translation
  FROM '/data/raw/product_category_name_translation.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COMMIT;
