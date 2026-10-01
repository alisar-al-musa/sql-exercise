

-- 8.	Find customers who placed an order in their first month but have not ordered again in the following 90 days (a basic churn definition).

-- Customers whose first order was never followed by another within 90 days.
-- The customer is customer_unique_id 

-- get first order date for each customer
WITH first_order AS (
    SELECT c.customer_unique_id AS customer,
           MIN(o.order_purchase_timestamp) AS first_ts
    FROM core.orders    AS o
    JOIN core.customers AS c ON c.customer_id = o.customer_id
    GROUP BY 1
)
-- find customers with no order within 90 days after their first order.
SELECT f.customer, f.first_ts
FROM first_order AS f
WHERE NOT EXISTS (
    SELECT 1
    FROM core.orders    AS o
    JOIN core.customers AS c ON c.customer_id = o.customer_id
    WHERE c.customer_unique_id = f.customer
      AND o.order_purchase_timestamp >  f.first_ts
      AND o.order_purchase_timestamp <= f.first_ts + INTERVAL '90 days'
);


-- result
--  9b382a02f201c7be3c6840e95e1dff12 | 2018-05-14 12:53:23
--  816a9d13b0b4a4c4b7c1015ba08deff1 | 2018-05-15 16:37:01
--  7675ea22236da5d26f0d27950f7fd3fa | 2018-04-12 03:50:51
--  958ac7760e5484df1496ba5833ab6117 | 2018-08-21 10:00:25
--  7674d7447392f12c0aa0743d1394f6f7 | 2018-05-10 06:59:35
--  bfabd561837fc8ae17420e8d97818ea6 | 2018-05-07 13:06:12
--  f5b080930d88f9d787e499810b108229 | 2017-03-15 12:02:38
--  5fa46f6e9387b360002615c36c0ae68e | 2017-05-18 06:54:10
--  fd39eafefd858bd09aeb583cf3c5c38c | 2018-01-19 10:41:52
--  08e5461c0b53fb083f56f9d45a15e12e | 2018-04-01 18:19:53
--  34c6f984b590bbfe3d4d6c76007c0b1c | 2017-11-28 08:43:12
--  0d519cfe31689fabcab064df5c93e693 | 2018-04-04 14:16:51
--  03a4afe75c961114945607707b9f3b88 | 2017-06-06 23:21:00
--  4a06cf383c4c56edbbe4b907fb955592 | 2018-04-14 11:42:40
--  398e70ea299343c456dffc65853935b4 | 2017-08-24 10:09:31
--  784cb4bb6f10b1951129e20b3e0ae20b | 2018-08-20 21:12:57
--  a856637b6dd58cf71bfbf7b6a21d8d84 | 2018-07-21 16:48:08
--  36cb06fed5371d8e5ae0074141da1ae2 | 2018-05-13 21:50:26
--  322b626c652eccf3b4f90768ed128ca0 | 2018-07-29 07:42:55
--  33ddcd40663a64855859856928c38415 | 2017-08-17 17:25:39
