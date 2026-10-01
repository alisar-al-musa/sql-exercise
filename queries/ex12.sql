

-- 12.  Checkpoint Q3: What fraction of customers are repeat buyers, and how
--      does average order value differ between one-time and repeat customers?

-- The order_spend CTE is the same one written in ex9 -- collapse payments to
-- one row per order first, because an order can have several payment rows
-- (installments, voucher + card) and joining payments straight to customers
-- would count those orders twice.



WITH order_spend AS (
    SELECT O.order_id,
           C.customer_unique_id,
           SUM(P.payment_value) AS order_total
    FROM core.orders    AS O
    JOIN core.customers AS C ON C.customer_id = O.customer_id
    JOIN core.payments  AS P ON P.order_id    = O.order_id
    WHERE O.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY O.order_id, C.customer_unique_id
),
per_customer AS (
    SELECT customer_unique_id,
           COUNT(*)         AS order_count,
           SUM(order_total) AS total_spend
    FROM order_spend
    GROUP BY customer_unique_id
)
SELECT
    CASE WHEN order_count = 1 THEN 'one-time' ELSE 'repeat' END AS customer_type,
    COUNT(*) AS customers,
    -- SUM(COUNT(*)) OVER () is the grand total of both groups, so this is each
    -- group's share of all customers.
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers,
    SUM(order_count) AS num_orders,
    -- devide by order count to get the AVG, can not use AVG directly, since we are using per customer data not per order.
    ROUND(SUM(total_spend) / SUM(order_count), 2) AS avg_order_value
FROM per_customer
GROUP BY 1
ORDER BY 1;


-- results

--  customer_type | customers | pct_of_customers | num_orders | avg_order_value
-- ---------------+-----------+------------------+------------+-----------------
--  one-time      |     92100 |            96.96 |  92100     |      161.22
--  repeat        |      2888 |             3.04 |   6105     |      145.87
-- (2 rows)


-- interpretation

-- Only 3.04% of customers ever buy twice -- 2,888 people out of 94,988. That is
-- very low for a marketplace and matches the churn picture in ex8.
-- Repeat customers also spend LESS per order, not more: R$145.87 against
-- R$161.22, about 10% below one-time buyers. So the usual assumption that loyal
-- customers are worth more per basket does not hold here; their value comes
-- from buying 2.1 times on average rather than from bigger orders.
