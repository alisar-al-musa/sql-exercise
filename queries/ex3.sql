

-- 3.	Total revenue per month, across the full dataset.

-- use payment_value, since it includes frieght also, while price not
-- for price: some orders does not list their order items.

SELECT DATE_TRUNC('month', O.order_purchase_timestamp)::date  AS months, SUM(P.payment_value) AS revenue
FROM core.orders AS O
JOIN core.payments AS P ON P.order_id = O.order_id
--filter the canceled and unavailable ones, since their payments are fake (~143k)
WHERE O.order_status <> 'canceled' AND o.order_status <> 'unavailable'
GROUP BY 1
ORDER BY 1


--    months   |  revenue   
-- ------------+------------
--  2016-09-01 |     136.23
--  2016-10-01 |   53915.50
--  2016-12-01 |      19.62
--  2017-01-01 |  138119.76
--  2017-02-01 |  289081.01
--  2017-03-01 |  442406.37
--  2017-04-01 |  409846.01
--  2017-05-01 |  588335.96
--  2017-06-01 |  507302.62
--  2017-07-01 |  585331.36
--  2017-08-01 |  667224.47
--  2017-09-01 |  723781.27
--  2017-10-01 |  773104.35
--  2017-11-01 | 1187224.36
--  2017-12-01 |  874962.23
--  2018-01-01 | 1109464.00
--  2018-02-01 |  984790.19
--  2018-03-01 | 1156243.76
--  2018-04-01 | 1157336.33
--  2018-05-01 | 1149483.77
--  2018-06-01 | 1021220.02
--  2018-07-01 | 1047422.72
--  2018-08-01 |  998504.15
--  2018-09-01 |     166.46
-- (24 rows)
