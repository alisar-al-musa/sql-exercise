

-- 9.	Using a CTE, rewrite the running-total-spend exercise from Section 5.3 and compare readability against the original.

WITH order_spend AS (
    SELECT O.order_id,
           C.customer_unique_id,
           O.order_purchase_timestamp,
           SUM(P.payment_value) AS order_total
    FROM core.orders    AS O
    JOIN core.customers AS C ON C.customer_id = O.customer_id
    JOIN core.payments  AS P ON P.order_id    = O.order_id
    GROUP BY O.order_id, C.customer_unique_id, O.order_purchase_timestamp
)
SELECT customer_unique_id,
       order_purchase_timestamp,
       order_total,
       SUM(order_total) OVER (
           PARTITION BY customer_unique_id
           ORDER BY order_purchase_timestamp
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW -- this indicates the window included in the running sum.
       ) AS running_total
FROM order_spend
ORDER BY customer_unique_id, order_purchase_timestamp;



-- results 

-- 8632f0bb1bedf53702cc4b | 2018-03-07 17:15:10      |       85.37 |         85.37
--  ffe6305176b9431a3eda3cf8904d7eb7 | 2018-06-09 20:40:23      |       57.37 |         57.37
--  ffe6efca3c7e6a06bad0a6a883280a93 | 2018-01-24 11:31:35      |      226.90 |        226.90
--  ffe76cb2f4bb39384c432d65ece67441 | 2018-04-25 10:26:29      |       66.06 |         66.06
--  ffe7752edcf14b5819058b1948e02f3a | 2017-06-13 21:25:18      |       71.15 |         71.15
--  ffe780a8995715d9560ca10f3351710f | 2017-08-10 12:44:46      |      142.50 |        142.50
--  ffe8f2fc0cee48f79934bd2c506fafc0 | 2017-08-02 14:08:19      |      111.42 |        111.42
--  ffe9102bb78a76921ba0ff3c4659616a | 2017-06-09 13:25:52      |      416.36 |        416.36
--  ffe96201d466b0e0dc8139850be29d5d | 2018-07-16 16:35:30      |       96.42 |         96.42
--  ffe96c782a5bc522bd8bad3bc638981a | 2018-07-30 14:17:23      |      245.22 |        245.22
--  ffe9be10b9a58c5464d833e8b1b2c632 | 2017-11-27 14:18:56      |      155.73 |        155.73
--  ffe9e41fbd14db4a7361347c56af5447 | 2018-02-11 12:51:07      |      220.88 |        220.88
--  ffeb904468642a1ce663a322629801cb | 2018-06-27 11:57:41      |       93.11 |         93.11
--  ffebb6424578e7bb153322da9d65634f | 2017-01-16 14:04:11      |      665.70 |        665.70
--  ffec10ad4229ba46818560e1c8b40a68 | 2018-04-05 05:11:57      |      135.72 |        135.72
--  ffec490ab531184a483efe2eedd68908 | 2018-08-03 14:52:31      |       57.98 |         57.98
--  ffecceca389973ef16660d58696f281e | 2018-04-25 12:08:11      |       72.76 |         72.76
--  ffeddf8aa7cdecf403e77b2e9a99e2ea | 2018-05-13 16:04:51      |      204.20 |        204.20
--  ffedff0547d809c90c05c2691c51f9b7 | 2017-03-30 14:50:26      |       32.42 |         32.42
--  ffee94d548cef05b146d825a7648dab4 | 2018-07-27 22:40:35      |       35.36 |         35.36
--  ffeefd086fc667aaf6595c8fe3d22d54 | 2017-09-27 07:26:22      |       62.94 |         62.94
--  ffef0ffa736c7b3d9af741611089729b | 2017-05-29 22:07:05      |      139.07 |        139.07
--  fff1afc79f6b5db1e235a4a6c30ceda7 | 2017-08-30 23:38:43      |       50.09 |         50.09
--  fff1bdd5c5e37ca79dd74deeb91aa5b6 | 2018-02-24 17:38:14      |      172.98 |        172.98
--  fff22793223fe80c97a8fd02ac5c6295 | 2018-06-26 11:01:47      |       89.19 |         89.19
--  fff2ae16b99c6f3c785f0e052f2a9cfb | 2018-04-20 11:03:47      |      200.90 |        200.90
--  fff3a9369e4b7102fab406a334a678c3 | 2017-08-11 10:26:38      |      102.74 |        102.74
--  fff3e1d7bc75f11dc7670619b2e61840 | 2018-07-20 13:47:30      |       82.51 |         82.51
--  fff5eb4918b2bf4b2da476788d42051c | 2018-07-02 16:39:59      |     2844.96 |       2844.96
--  fff699c184bcc967d62fa2c6171765f7 | 2017-09-01 17:06:54      |       55.00 |         55.00
--  fff7219c86179ca6441b8f37823ba3d3 | 2017-12-27 18:57:38      |      265.80 |        265.80
--  fff96bc586f78b1f070da28c4977e810 | 2018-08-15 10:26:57      |       63.42 |         63.42
--  fffa431dd3fcdefea4b1777d114144f2 | 2017-10-30 20:39:50      |       81.20 |         81.20
--  fffb09418989a0dbff854a28163e47c6 | 2017-12-17 19:14:35      |       73.16 |         73.16
--  fffbf87b7a1a6fa8b03f081c5f51a201 | 2017-12-27 22:36:41      |      167.32 |        167.32
--  fffcc512b7dfecaffd80f13614af1d16 | 2018-04-11 00:34:32      |      710.70 |        710.70
--  fffcf5a5ff07b0908bd4e2dbc735a684 | 2017-06-08 21:00:36      |     2067.42 |       2067.42
--  fffea47cd6d3cc0a88bd621562a9d061 | 2017-12-10 20:07:56      |       84.58 |         84.58
--  ffff371b4d645b6ecea244b27531430a | 2017-02-07 15:49:16      |      112.46 |        112.46
--  ffff5962728ec6157033ef9805bacc48 | 2018-05-02 15:17:41      |      133.69 |        133.69
--  ffffd2657e2aad2907e67c3e9daecbeb | 2017-05-02 20:18:45      |       71.56 |         71.56
-- (99439 rows)