-- Clean staging into the working schema.
--
-- Idempotent: every core table is truncated first, so re-running produces
-- identical row counts.
--
-- Four cleaning rules are applied here. Each was decided from measured
-- evidence; the reasoning is in docs/data-profile.md.
--   1. one order dropped, with its child rows
--   2. delivery date imputed for seven orders
--   3. order_reviews de-duplicated to one review per order
--   4. category translated with a fallback to the Portuguese name
-- Everything else is a straight cast: no value in staging fails to parse.

BEGIN;

TRUNCATE
  core.customers,
  core.geolocation,
  core.sellers,
  core.product_category_translation,
  core.products,
  core.orders,
  core.order_items,
  core.payments,
  core.order_reviews;

-- Rule 1. One order is marked 'delivered' but has neither a delivery date nor
-- a carrier date, so nothing in the source supports an estimate for it. It is
-- dropped, and its order_items, payment and review rows must go with it or
-- they would point at an order that no longer exists and break the foreign
-- keys added in Phase 2.
CREATE TEMP TABLE dropped_orders ON COMMIT DROP AS
SELECT order_id
FROM staging.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL
  AND order_delivered_carrier_date  IS NULL;

-- Reference data first. Apart from the customer below, nothing here needs
-- cleaning beyond casting.

-- Rule 1 continued. The dropped order's customer row goes with it. Olist mints
-- a fresh customer_id per order, so that row describes an order that no longer
-- exists; keeping it would leave core.customers one row larger than core.orders
-- and make "how many customers" disagree with "how many orders" in a 1:1 model.
-- Nothing is lost: the person behind it is identified by customer_unique_id,
-- and staging.customers keeps the original row untouched.
INSERT INTO core.customers
SELECT c.customer_id,
       c.customer_unique_id,
       c.customer_zip_code_prefix::integer,
       c.customer_city,
       c.customer_state
FROM staging.customers c
WHERE NOT EXISTS (
  SELECT 1
  FROM staging.orders o
  JOIN dropped_orders d ON d.order_id = o.order_id
  WHERE o.customer_id = c.customer_id);

-- DISTINCT removes 261,831 exactly-duplicated coordinate rows (1,000,163 ->
-- 738,332). Only whole-row duplicates go; two rows sharing a zip but differing
-- in coordinates or city are both real and both kept.
INSERT INTO core.geolocation
SELECT DISTINCT
       geolocation_zip_code_prefix::integer,
       geolocation_lat::numeric,
       geolocation_lng::numeric,
       geolocation_city,
       geolocation_state
FROM staging.geolocation;

INSERT INTO core.sellers
SELECT seller_id,
       seller_zip_code_prefix::integer,
       seller_city,
       seller_state
FROM staging.sellers;

INSERT INTO core.product_category_translation
SELECT product_category_name, product_category_name_english
FROM staging.product_category_name_translation;

-- Rule 4. LEFT JOIN, not INNER: thirteen products belong to two categories
-- absent from the translation file (portateis_cozinha_e_preparadores_de_
-- alimentos and pc_gamer). An INNER JOIN would silently delete those products.
-- COALESCE falls back to the Portuguese name rather than inventing a
-- translation, so no product loses its category.
INSERT INTO core.products
SELECT p.product_id,
       p.product_category_name,
       COALESCE(t.product_category_name_english, p.product_category_name),
       p.product_name_lenght::integer,
       p.product_description_lenght::integer,
       p.product_photos_qty::integer,
       p.product_weight_g::integer,
       p.product_length_cm::integer,
       p.product_height_cm::integer,
       p.product_width_cm::integer
FROM staging.products p
LEFT JOIN staging.product_category_name_translation t
       ON t.product_category_name = p.product_category_name;

-- Rule 2. Seven orders are marked 'delivered' with no delivery date but do
-- have a carrier date. The carrier date is a lower bound, not an estimate:
-- using it raw would assert a zero-day delivery. Adding 7.1 days -- the median
-- carrier-to-customer gap measured over the 96,469 delivered orders that have
-- both dates -- keeps delivery after handover without that bias.
--
-- Imputed rows are not flagged with a column; docs/data-profile.md is the
-- record of which rows were changed and why.
INSERT INTO core.orders
SELECT o.order_id,
       o.customer_id,
       o.order_status,
       o.order_purchase_timestamp::timestamp,
       o.order_approved_at::timestamp,
       o.order_delivered_carrier_date::timestamp,
       CASE
         WHEN o.order_status = 'delivered'
          AND o.order_delivered_customer_date IS NULL
          AND o.order_delivered_carrier_date  IS NOT NULL
         THEN o.order_delivered_carrier_date::timestamp + INTERVAL '7.1 days'
         ELSE o.order_delivered_customer_date::timestamp
       END,
       o.order_estimated_delivery_date::date
FROM staging.orders o
WHERE NOT EXISTS (SELECT 1 FROM dropped_orders d WHERE d.order_id = o.order_id);

INSERT INTO core.order_items
SELECT i.order_id,
       i.order_item_id::integer,
       i.product_id,
       i.seller_id,
       i.shipping_limit_date::timestamp,
       i.price::numeric(10,2),
       i.freight_value::numeric(10,2)
FROM staging.order_items i
WHERE NOT EXISTS (SELECT 1 FROM dropped_orders d WHERE d.order_id = i.order_id);

INSERT INTO core.payments
SELECT p.order_id,
       p.payment_sequential::integer,
       p.payment_type,
       p.payment_installments::integer,
       p.payment_value::numeric(10,2)
FROM staging.order_payments p
WHERE NOT EXISTS (SELECT 1 FROM dropped_orders d WHERE d.order_id = p.order_id);

-- Rule 3. 547 orders carry more than one review. An order logically has one
-- review, so these are data errors rather than a real one-to-many.
--
-- DISTINCT ON (order_id) keeps the first row per order under the ORDER BY, so
-- ordering by review_answer_timestamp DESC keeps the LATEST review. That
-- matters: 202 of the 547 disagree on score, typically a customer rating
-- optimistically and returning to rate again once the order arrived, or did
-- not. The later review is the settled verdict. review_answer_timestamp breaks
-- all 547 ties; review_creation_date would leave 157 unresolved and make the
-- result depend on physical row order.
INSERT INTO core.order_reviews
SELECT DISTINCT ON (r.order_id)
       r.order_id,
       r.review_id,
       r.review_score::integer,
       r.review_comment_title,
       r.review_comment_message,
       r.review_creation_date::timestamp,
       r.review_answer_timestamp::timestamp
FROM staging.order_reviews r
WHERE NOT EXISTS (SELECT 1 FROM dropped_orders d WHERE d.order_id = r.order_id)
ORDER BY r.order_id, r.review_answer_timestamp DESC;

COMMIT;
