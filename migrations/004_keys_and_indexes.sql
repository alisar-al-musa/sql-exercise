-- 004: Primary keys, foreign keys, CHECK constraints and indexes.
--
-- Phase 1 deliberately left core.* constraint-free so a bad value could never
-- abort a load. seed/04_verify_core.sql proved every key below is already
-- unique and every foreign key already holds, so nothing here can fail on the
-- current data. Each CHECK was likewise counted against the loaded rows before
-- being written; the ones the data refused are listed in section 4.


-- 1. Primary keys ------------------------------------------------------------

-- Unique per ORDER, not per person. The person is customer_unique_id (96,096
-- distinct); see the UNIQUE constraint in section 2 for what that implies.
ALTER TABLE core.customers
  ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);

ALTER TABLE core.sellers
  ADD CONSTRAINT sellers_pkey PRIMARY KEY (seller_id);

ALTER TABLE core.products
  ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);

ALTER TABLE core.product_category_translation
  ADD CONSTRAINT product_category_translation_pkey
  PRIMARY KEY (product_category_name);

ALTER TABLE core.orders
  ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);

-- Composite: order_item_id is a line number within the order (1-21), not an
-- identifier, so it is only unique alongside the order.
ALTER TABLE core.order_items
  ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, order_item_id);

-- Composite for the same reason: payment_sequential numbers the payments
-- within one order, so a split payment is several rows sharing an order_id.
ALTER TABLE core.payments
  ADD CONSTRAINT payments_pkey PRIMARY KEY (order_id, payment_sequential);

-- order_id, NOT review_id. An order has one review; the 547 orders that
-- carried more than one were de-duplicated in cleaning. review_id stays a
-- plain attribute because 789 review_ids legitimately appear against several
-- orders -- one review attached to each order of a multi-order purchase -- so
-- it can carry neither a primary key nor a UNIQUE constraint.
ALTER TABLE core.order_reviews
  ADD CONSTRAINT order_reviews_pkey PRIMARY KEY (order_id);

-- core.geolocation gets NO primary key, deliberately. No column or combination
-- of columns is unique even after whole-row de-duplication, and nothing
-- references an individual row. It is a coordinate lookup, not an entity.
-- A surrogate identity column would invent a key that nothing would ever use.

-- 2. Uniqueness beyond the primary keys --------------------------------------

-- The interesting one. Olist issues a fresh customer_id for every order, so
-- orders:customers is genuinely 1:1, not many-to-1. Declaring it makes the ERD
-- state something true rather than implying a many-to-1 that does not exist,
-- and it catches any future change that breaks the assumption.
ALTER TABLE core.orders
  ADD CONSTRAINT orders_customer_id_key UNIQUE (customer_id);

-- 3. Foreign keys ------------------------------------------------------------
--
-- ON DELETE is left at the default (NO ACTION) rather than CASCADE. CASCADE
-- exists to make deletes convenient, and this warehouse is rebuilt from CSVs
-- rather than edited. What NO ACTION buys is that a delete which would strand
-- child rows fails loudly instead of silently removing them.

ALTER TABLE core.orders
  ADD CONSTRAINT orders_customer_id_fkey
  FOREIGN KEY (customer_id) REFERENCES core.customers (customer_id);

ALTER TABLE core.order_items
  ADD CONSTRAINT order_items_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES core.orders (order_id);

ALTER TABLE core.order_items
  ADD CONSTRAINT order_items_product_id_fkey
  FOREIGN KEY (product_id) REFERENCES core.products (product_id);

ALTER TABLE core.order_items
  ADD CONSTRAINT order_items_seller_id_fkey
  FOREIGN KEY (seller_id) REFERENCES core.sellers (seller_id);

ALTER TABLE core.payments
  ADD CONSTRAINT payments_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES core.orders (order_id);

ALTER TABLE core.order_reviews
  ADD CONSTRAINT order_reviews_order_id_fkey
  FOREIGN KEY (order_id) REFERENCES core.orders (order_id);

-- Three foreign keys a reader might expect are deliberately absent, each
-- because the data refuses them:
--
--   products.product_category_name -> product_category_translation
--       13 products belong to two categories missing from the 71-row
--       translation file. Declared as an FK, those products would have to be
--       deleted. Treated as a lookup and LEFT JOINed instead.
--
--   customers.customer_zip_code_prefix -> geolocation   (157 zips missing)
--   sellers.seller_zip_code_prefix     -> geolocation     (7 zips missing)
--       geolocation does not cover every zip prefix in use, so it cannot be a
--       parent. It is a lookup, always LEFT JOINed.

-- 4. CHECK constraints -------------------------------------------------------
--
-- Only rules the loaded data actually satisfies, each counted first. These
-- record facts about the domain, not preferences.

-- The documented Olist rating scale, and the observed range is exactly 1-5.
ALTER TABLE core.order_reviews
  ADD CONSTRAINT order_reviews_score_range CHECK (review_score BETWEEN 1 AND 5);

-- Money is non-negative. >= 0 rather than > 0: freight is legitimately 0.00 on
-- free-shipping lines and one payment row is 0.00, so requiring a positive
-- amount would be a business rule we invented, not something the data states.
ALTER TABLE core.order_items
  ADD CONSTRAINT order_items_amounts_non_negative
  CHECK (price >= 0 AND freight_value >= 0);

ALTER TABLE core.payments
  ADD CONSTRAINT payments_value_non_negative CHECK (payment_value >= 0);

-- Sequence numbers count from 1; installments count from 0 (observed minimum).
ALTER TABLE core.order_items
  ADD CONSTRAINT order_items_line_number_positive CHECK (order_item_id >= 1);

ALTER TABLE core.payments
  ADD CONSTRAINT payments_sequential_positive
  CHECK (payment_sequential >= 1 AND payment_installments >= 0);

-- Physically possible coordinates. Not a Brazilian bounding box: 33 rows fall
-- outside one, and they are real source rows we have no grounds to reject.
ALTER TABLE core.geolocation
  ADD CONSTRAINT geolocation_coords_valid
  CHECK (geolocation_lat BETWEEN -90 AND 90
     AND geolocation_lng BETWEEN -180 AND 180);

-- The two event orderings that actually hold across every row.
ALTER TABLE core.orders
  ADD CONSTRAINT orders_approved_after_purchase
  CHECK (order_approved_at >= order_purchase_timestamp);

ALTER TABLE core.order_reviews
  ADD CONSTRAINT order_reviews_answered_after_creation
  CHECK (review_answer_timestamp >= review_creation_date);

-- The closed sets of values present in the source. These document the domain,
-- but they are the constraints most likely to need editing if the dataset is
-- ever extended: a genuinely new status would be rejected on load.
ALTER TABLE core.orders
  ADD CONSTRAINT orders_status_known CHECK (order_status IN (
    'approved', 'canceled', 'created', 'delivered',
    'invoiced', 'processing', 'shipped', 'unavailable'));

ALTER TABLE core.payments
  ADD CONSTRAINT payments_type_known CHECK (payment_type IN (
    'boleto', 'credit_card', 'debit_card', 'not_defined', 'voucher'));

-- Four CHECKs that look obviously correct were tested and REJECTED, because
-- the source violates them. Declaring any one would fail this migration:
--
--   order_delivered_carrier_date  >= order_purchase_timestamp     -- 166 rows
--   order_delivered_customer_date >= order_delivered_carrier_date --  23 rows
--   product_weight_g > 0                                          --   4 rows
--   coordinates within a Brazilian bounding box                   --  33 rows
--
-- These are source noise. Silently deleting 193 real rows to satisfy a
-- constraint we invented would be worse than recording that the noise exists;
-- docs/data-profile.md carries the detail.

-- 5. Indexes -----------------------------------------------------------------
--
-- Primary keys and UNIQUE constraints already created their own indexes, and a
-- composite index serves queries on its LEADING column. So these are already
-- covered and are not repeated here:
--   order_items(order_id)   -- leading column of the primary key
--   payments(order_id)      -- leading column of the primary key
--   order_reviews(order_id) -- is the primary key
--   orders(customer_id)     -- from the UNIQUE constraint in section 2
--
-- PostgreSQL does NOT index foreign keys automatically, so the child-side
-- columns below need explicit indexes.

-- Every time-series question scans or groups on the purchase date.
CREATE INDEX IF NOT EXISTS orders_purchase_timestamp_idx
  ON core.orders (order_purchase_timestamp);

-- Foreign keys joined on constantly, and not covered by the composite PK.
CREATE INDEX IF NOT EXISTS order_items_product_id_idx
  ON core.order_items (product_id);

CREATE INDEX IF NOT EXISTS order_items_seller_id_idx
  ON core.order_items (seller_id);

-- 73 categories over 32,951 products: selective enough to be worth grouping on.
CREATE INDEX IF NOT EXISTS products_category_english_idx
  ON core.products (product_category_name_english);

-- 96,096 distinct values -- the lookup for counting real people rather than
-- orders, which customer_id cannot answer.
CREATE INDEX IF NOT EXISTS customers_unique_id_idx
  ON core.customers (customer_unique_id);

-- The only sane way to join a 738,332-row lookup that has no primary key.
CREATE INDEX IF NOT EXISTS geolocation_zip_code_prefix_idx
  ON core.geolocation (geolocation_zip_code_prefix);

-- Indexes deliberately NOT created, because they would not be used:
--
--   orders(order_delivered_customer_date)
--       The late-delivery question compares it to another column in the SAME
--       row (> order_estimated_delivery_date). A single-column btree cannot
--       serve a column-to-column comparison; the planner scans regardless.
--
--   orders(order_status)        -- 8 values, and 'delivered' is 97% of rows
--   customers(customer_state)   -- 27 values
--   payments(payment_type)      -- 5 values
--   order_reviews(review_score) -- 5 values
--       Too low-selectivity to beat a sequential scan. An index the planner
--       ignores still costs write time and disk on every rebuild.
