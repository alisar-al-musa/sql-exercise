-- Data profiling of staging. Read-only: makes no changes.
-- Produces the evidence recorded in docs/data-profile.md.

\echo '===== 1. KEY UNIQUENESS'
SELECT 'orders.order_id' AS candidate_key, count(*) AS rows, count(DISTINCT order_id) AS distinct_vals FROM staging.orders
UNION ALL SELECT 'customers.customer_id',        count(*), count(DISTINCT customer_id)        FROM staging.customers
UNION ALL SELECT 'customers.customer_unique_id', count(*), count(DISTINCT customer_unique_id) FROM staging.customers
UNION ALL SELECT 'products.product_id',          count(*), count(DISTINCT product_id)         FROM staging.products
UNION ALL SELECT 'sellers.seller_id',            count(*), count(DISTINCT seller_id)          FROM staging.sellers
UNION ALL SELECT 'order_reviews.review_id',      count(*), count(DISTINCT review_id)          FROM staging.order_reviews
UNION ALL SELECT 'order_reviews.order_id',       count(*), count(DISTINCT order_id)           FROM staging.order_reviews
UNION ALL SELECT 'order_reviews (review_id, order_id)', count(*), count(DISTINCT (review_id, order_id)) FROM staging.order_reviews
UNION ALL SELECT 'order_items (order_id, order_item_id)', count(*), count(DISTINCT (order_id, order_item_id)) FROM staging.order_items
UNION ALL SELECT 'order_payments (order_id, payment_sequential)', count(*), count(DISTINCT (order_id, payment_sequential)) FROM staging.order_payments
ORDER BY 1;

\echo ''
\echo '===== 2. CAST VALIDITY (pg_input_is_valid tests a cast without raising)'
SELECT 'orders.order_purchase_timestamp' AS col,
       count(*) FILTER (WHERE order_purchase_timestamp IS NOT NULL) AS non_null,
       count(*) FILTER (WHERE order_purchase_timestamp IS NOT NULL AND NOT pg_input_is_valid(order_purchase_timestamp,'timestamp')) AS bad FROM staging.orders
UNION ALL SELECT 'orders.order_approved_at', count(*) FILTER (WHERE order_approved_at IS NOT NULL),
       count(*) FILTER (WHERE order_approved_at IS NOT NULL AND NOT pg_input_is_valid(order_approved_at,'timestamp')) FROM staging.orders
UNION ALL SELECT 'orders.order_delivered_carrier_date', count(*) FILTER (WHERE order_delivered_carrier_date IS NOT NULL),
       count(*) FILTER (WHERE order_delivered_carrier_date IS NOT NULL AND NOT pg_input_is_valid(order_delivered_carrier_date,'timestamp')) FROM staging.orders
UNION ALL SELECT 'orders.order_delivered_customer_date', count(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL),
       count(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL AND NOT pg_input_is_valid(order_delivered_customer_date,'timestamp')) FROM staging.orders
UNION ALL SELECT 'orders.order_estimated_delivery_date', count(*) FILTER (WHERE order_estimated_delivery_date IS NOT NULL),
       count(*) FILTER (WHERE order_estimated_delivery_date IS NOT NULL AND NOT pg_input_is_valid(order_estimated_delivery_date,'timestamp')) FROM staging.orders
UNION ALL SELECT 'order_items.shipping_limit_date', count(*) FILTER (WHERE shipping_limit_date IS NOT NULL),
       count(*) FILTER (WHERE shipping_limit_date IS NOT NULL AND NOT pg_input_is_valid(shipping_limit_date,'timestamp')) FROM staging.order_items
UNION ALL SELECT 'order_items.price -> numeric', count(*) FILTER (WHERE price IS NOT NULL),
       count(*) FILTER (WHERE price IS NOT NULL AND NOT pg_input_is_valid(price,'numeric')) FROM staging.order_items
UNION ALL SELECT 'order_items.freight_value -> numeric', count(*) FILTER (WHERE freight_value IS NOT NULL),
       count(*) FILTER (WHERE freight_value IS NOT NULL AND NOT pg_input_is_valid(freight_value,'numeric')) FROM staging.order_items
UNION ALL SELECT 'order_payments.payment_value -> numeric', count(*) FILTER (WHERE payment_value IS NOT NULL),
       count(*) FILTER (WHERE payment_value IS NOT NULL AND NOT pg_input_is_valid(payment_value,'numeric')) FROM staging.order_payments
UNION ALL SELECT 'order_reviews.review_score -> int', count(*) FILTER (WHERE review_score IS NOT NULL),
       count(*) FILTER (WHERE review_score IS NOT NULL AND NOT pg_input_is_valid(review_score,'integer')) FROM staging.order_reviews
UNION ALL SELECT 'products.product_weight_g -> int', count(*) FILTER (WHERE product_weight_g IS NOT NULL),
       count(*) FILTER (WHERE product_weight_g IS NOT NULL AND NOT pg_input_is_valid(product_weight_g,'integer')) FROM staging.products
UNION ALL SELECT 'products.product_photos_qty -> int', count(*) FILTER (WHERE product_photos_qty IS NOT NULL),
       count(*) FILTER (WHERE product_photos_qty IS NOT NULL AND NOT pg_input_is_valid(product_photos_qty,'integer')) FROM staging.products
UNION ALL SELECT 'geolocation.lat -> numeric', count(*) FILTER (WHERE geolocation_lat IS NOT NULL),
       count(*) FILTER (WHERE geolocation_lat IS NOT NULL AND NOT pg_input_is_valid(geolocation_lat,'numeric')) FROM staging.geolocation
ORDER BY 1;

\echo ''
\echo '===== 3. MISSING TIMESTAMPS BY ORDER STATUS'
SELECT order_status, count(*) AS orders,
       count(*) FILTER (WHERE order_approved_at             IS NULL) AS no_approved,
       count(*) FILTER (WHERE order_delivered_carrier_date  IS NULL) AS no_carrier,
       count(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS no_delivered
FROM staging.orders GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '===== 3b. DUPLICATE SHAPE IN order_reviews'
SELECT dup_count AS reviews_per_order, count(*) AS how_many_orders
FROM (SELECT order_id, count(*) AS dup_count FROM staging.order_reviews GROUP BY order_id) t
GROUP BY 1 ORDER BY 1;

SELECT dup_count AS rows_per_review_id, count(*) AS how_many_review_ids
FROM (SELECT review_id, count(*) AS dup_count FROM staging.order_reviews GROUP BY review_id) t
GROUP BY 1 ORDER BY 1;

\echo ''
\echo '===== 4. REFERENTIAL INTEGRITY (orphan = child value with no parent)'
SELECT 'orders.customer_id -> customers' AS fk, count(*) AS orphan_rows FROM staging.orders o
  WHERE NOT EXISTS (SELECT 1 FROM staging.customers c WHERE c.customer_id = o.customer_id)
UNION ALL SELECT 'order_items.order_id -> orders', count(*) FROM staging.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM staging.orders o WHERE o.order_id = i.order_id)
UNION ALL SELECT 'order_items.product_id -> products', count(*) FROM staging.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM staging.products p WHERE p.product_id = i.product_id)
UNION ALL SELECT 'order_items.seller_id -> sellers', count(*) FROM staging.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM staging.sellers s WHERE s.seller_id = i.seller_id)
UNION ALL SELECT 'order_payments.order_id -> orders', count(*) FROM staging.order_payments p
  WHERE NOT EXISTS (SELECT 1 FROM staging.orders o WHERE o.order_id = p.order_id)
UNION ALL SELECT 'order_reviews.order_id -> orders', count(*) FROM staging.order_reviews r
  WHERE NOT EXISTS (SELECT 1 FROM staging.orders o WHERE o.order_id = r.order_id)
UNION ALL SELECT 'products.category -> translation', count(*) FROM staging.products p
  WHERE p.product_category_name IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM staging.product_category_name_translation t
                    WHERE t.product_category_name = p.product_category_name)
ORDER BY 2 DESC, 1;

\echo ''
\echo '===== 4b. WHICH CATEGORIES ARE MISSING A TRANSLATION?'
SELECT p.product_category_name, count(*) AS products
FROM staging.products p
WHERE p.product_category_name IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging.product_category_name_translation t
                  WHERE t.product_category_name = p.product_category_name)
GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '===== 5. COVERAGE GAPS (decide INNER vs LEFT JOIN)'
SELECT 'orders with no order_items' AS gap, count(*) FROM staging.orders o
  WHERE NOT EXISTS (SELECT 1 FROM staging.order_items i WHERE i.order_id = o.order_id)
UNION ALL SELECT 'orders with no review', count(*) FROM staging.orders o
  WHERE NOT EXISTS (SELECT 1 FROM staging.order_reviews r WHERE r.order_id = o.order_id)
UNION ALL SELECT 'orders with no payment', count(*) FROM staging.orders o
  WHERE NOT EXISTS (SELECT 1 FROM staging.order_payments p WHERE p.order_id = o.order_id)
UNION ALL SELECT 'products with NULL category', count(*) FROM staging.products WHERE product_category_name IS NULL
UNION ALL SELECT 'products never ordered', count(*) FROM staging.products p
  WHERE NOT EXISTS (SELECT 1 FROM staging.order_items i WHERE i.product_id = p.product_id)
ORDER BY 2 DESC;

\echo ''
\echo '===== 6. ENCODING: the first loaded category must not carry a BOM'
SELECT product_category_name,
       encode(convert_to(product_category_name,'UTF8'),'hex') AS hex
FROM staging.product_category_name_translation LIMIT 1;
