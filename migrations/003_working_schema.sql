-- 003: The working schema -- staging's TEXT columns given real types.
--
-- Types were chosen from measured evidence, not from column names; see
-- docs/data-profile.md. Every value in staging was tested with
-- pg_input_is_valid and not one fails to cast, so the inserts in
-- seed/02_clean.sql cast directly with no sanitising or quarantine table.
--
-- NOT NULL is declared only where the profile proved zero nulls. Columns that
-- genuinely have missing values stay nullable -- NULL here means "did not
-- happen", which is true of an undelivered order.
--
-- Primary keys, foreign keys and indexes are deliberately NOT here. The brief
-- puts them in Phase 2, and seed/03_verify_core.sql proves each intended key is
-- unique in the meantime, so Phase 2 can add the constraints knowing they hold.

CREATE SCHEMA IF NOT EXISTS core;

CREATE TABLE IF NOT EXISTS core.customers (
  -- Unique per ORDER, not per person: Olist mints a fresh customer_id each
  -- time. The person is customer_unique_id (96,096 distinct). Counting
  -- customer_id counts orders.
  customer_id               TEXT    NOT NULL,
  customer_unique_id        TEXT    NOT NULL,
  customer_zip_code_prefix  INTEGER NOT NULL,
  customer_city             TEXT    NOT NULL,
  customer_state            TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS core.geolocation (
  -- A coordinate lookup, not an entity table: no column or combination is
  -- unique. NUMERIC is unconstrained so coordinates keep their full precision.
  geolocation_zip_code_prefix  INTEGER NOT NULL,
  geolocation_lat              NUMERIC NOT NULL,
  geolocation_lng              NUMERIC NOT NULL,
  geolocation_city             TEXT    NOT NULL,
  geolocation_state            TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS core.sellers (
  seller_id               TEXT    NOT NULL,
  seller_zip_code_prefix  INTEGER NOT NULL,
  seller_city             TEXT    NOT NULL,
  seller_state            TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS core.product_category_translation (
  product_category_name          TEXT NOT NULL,
  product_category_name_english  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.products (
  product_id                  TEXT NOT NULL,
  -- 610 products have no category, so both name columns are nullable.
  -- The English name falls back to the Portuguese one for the two categories
  -- missing from the translation file; see seed/02_clean.sql.
  product_category_name          TEXT,
  product_category_name_english  TEXT,
  -- 'lenght' in the source CSV. Corrected here -- this is the last point at
  -- which the typo exists.
  product_name_length         INTEGER,
  product_description_length  INTEGER,
  product_photos_qty          INTEGER,
  product_weight_g            INTEGER,
  product_length_cm           INTEGER,
  product_height_cm           INTEGER,
  product_width_cm            INTEGER
);

CREATE TABLE IF NOT EXISTS core.orders (
  order_id                       TEXT      NOT NULL,
  customer_id                    TEXT      NOT NULL,
  order_status                   TEXT      NOT NULL,
  order_purchase_timestamp       TIMESTAMP NOT NULL,
  -- Nullable by design: an order that was never approved, handed to a carrier
  -- or delivered has no such date. 2,957 of the 2,965 missing delivery dates
  -- are explained by order_status alone.
  order_approved_at              TIMESTAMP,
  order_delivered_carrier_date   TIMESTAMP,
  order_delivered_customer_date  TIMESTAMP,
  -- DATE, not TIMESTAMP: every one of the 99,441 values is exactly midnight,
  -- so TIMESTAMP would imply a precision the source does not have.
  order_estimated_delivery_date  DATE      NOT NULL
);

CREATE TABLE IF NOT EXISTS core.order_items (
  order_id             TEXT          NOT NULL,
  -- A line number within the order (1-21), not an identifier.
  order_item_id        INTEGER       NOT NULL,
  product_id           TEXT          NOT NULL,
  seller_id            TEXT          NOT NULL,
  shipping_limit_date  TIMESTAMP     NOT NULL,
  price                NUMERIC(10,2) NOT NULL,
  freight_value        NUMERIC(10,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.payments (
  order_id              TEXT          NOT NULL,
  payment_sequential    INTEGER       NOT NULL,
  payment_type          TEXT          NOT NULL,
  payment_installments  INTEGER       NOT NULL,
  payment_value         NUMERIC(10,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.order_reviews (
  -- order_id is the key here, not review_id: an order has one review, and the
  -- 547 orders carrying more than one are de-duplicated during cleaning.
  order_id                 TEXT      NOT NULL,
  -- NOT unique: 789 review_ids appear against several orders, which is one
  -- person's review attached to each of their orders. Kept as an attribute.
  review_id                TEXT      NOT NULL,
  review_score             INTEGER   NOT NULL,
  -- 87,656 reviews have no title and 58,247 no message.
  review_comment_title     TEXT,
  review_comment_message   TEXT,
  review_creation_date     TIMESTAMP NOT NULL,
  review_answer_timestamp  TIMESTAMP NOT NULL
  -- embedding VECTOR(1024) is added in Phase 2.
);
