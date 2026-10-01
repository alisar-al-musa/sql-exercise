

-- 10.  Checkpoint Q1: Which product category generates the most revenue,
--      and has that changed month over month?

-- Revenue here is SUM(order_items.price), NOT payment_value.
-- A payment is attached to the whole order, so it cannot be split between the
-- categories inside that order. price is per line, so it can.
-- Freight is left out: it is a shipping cost, not category sales.

-- Part A -- the overall winner.

SELECT
    COALESCE(PR.product_category_name_english, 'unknown') AS category,
    SUM(I.price) AS revenue
FROM core.order_items AS I
JOIN core.orders   AS O  ON O.order_id    = I.order_id
JOIN core.products AS PR ON PR.product_id = I.product_id
WHERE O.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;


-- Part B -- the winner in each month.
-- RANK() PARTITION BY month restarts the ranking inside every month,
-- so rank_in_month = 1 is that month's best category.

WITH monthly AS (
    SELECT DATE_TRUNC('month', O.order_purchase_timestamp)::date AS month,
           COALESCE(PR.product_category_name_english, 'unknown') AS category,
           SUM(I.price) AS revenue
    FROM core.order_items AS I
    JOIN core.orders   AS O  ON O.order_id    = I.order_id
    JOIN core.products AS PR ON PR.product_id = I.product_id
    WHERE O.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2
),
ranked AS (
    SELECT month, category, revenue,
           RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS rank_in_month
    FROM monthly
)
SELECT month, category, revenue
FROM ranked
WHERE rank_in_month = 1
ORDER BY month;


-- results

-- Part A
--        category        |  revenue
-- -----------------------+------------
--  health_beauty         | 1255695.13
--  watches_gifts         | 1198185.21
--  bed_bath_table        | 1035964.06
--  sports_leisure        |  979561.92
--  computers_accessories |  904322.02
--  furniture_decor       |  727465.05
--  housewares            |  626825.80
--  cool_stuff            |  620770.49
--  auto                  |  586585.73
--  garden_tools          |  481009.94
-- (10 rows)

-- Part B
--    month    |                category                 |  revenue
-- ------------+-----------------------------------------+-----------
--  2016-09-01 | health_beauty                           |    134.97
--  2016-10-01 | furniture_decor                         |   5807.89
--  2016-12-01 | fashion_bags_accessories                |     10.90
--  2017-01-01 | furniture_decor                         |  13521.31
--  2017-02-01 | health_beauty                           |  22838.79
--  2017-03-01 | computers_accessories                   |  28145.60
--  2017-04-01 | bed_bath_table                          |  24347.69
--  2017-05-01 | health_beauty                           |  46786.02
--  2017-06-01 | cool_stuff                              |  38244.50
--  2017-07-01 | bed_bath_table                          |  63838.85
--  2017-08-01 | bed_bath_table                          |  57067.33
--  2017-09-01 | computers                               |  52878.88
--  2017-10-01 | watches_gifts                           |  65060.53
--  2017-11-01 | watches_gifts                           |  96575.58
--  2017-12-01 | watches_gifts                           |  71611.62
--  2018-01-01 | sports_leisure                          |  91368.43
--  2018-02-01 | computers_accessories                   | 100367.79
--  2018-03-01 | watches_gifts                           |  97861.08
--  2018-04-01 | watches_gifts                           |  92658.57
--  2018-05-01 | watches_gifts                           | 123872.66
--  2018-06-01 | health_beauty                           | 107795.99
--  2018-07-01 | health_beauty                           | 105517.68
--  2018-08-01 | health_beauty                           | 120475.71
--  2018-09-01 | kitchen_dining_laundry_garden_furniture |    145.00
-- (24 rows)


-- interpretation

-- health_beauty is the biggest category overall at R$1.26M, just ahead of
-- watches_gifts at R$1.20M -- a 5% gap, so the lead is real but not safe.
-- Yes, it changes month over month: nine different categories win at least one
-- month. watches_gifts owns late 2017 and most of early 2018 (it peaks at
-- R$123.9k in 2018-05), then health_beauty takes the last three full months.
-- The first and last months (2016-09, 2016-12, 2018-09) have almost no volume,
-- so their winners are noise, not a trend.
