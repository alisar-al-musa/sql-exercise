

-- 13.  Checkpoint Q4: one open-ended question of my own.
--
--      Question: does a late delivery actually hurt the review score, and how
--      badly? ex1 already found the late orders; this asks what they cost.8

-- "Late" is the same test as ex1: the real delivery date is after the date the
-- customer was promised. Both sides are compared as DATE 

-- Only delivered orders can be judged: an order still in transit has no
-- delivery date, so it is neither on time nor late yet.

-- days_late is negative when the order arrived early, which lets one CASE
-- cover early, on-time and late in a single scale.

WITH delivered AS (
    SELECT O.order_id,
           (O.order_delivered_customer_date::date - O.order_estimated_delivery_date) AS days_late,
           R.review_score
    FROM core.orders        AS O
    JOIN core.order_reviews AS R ON R.order_id = O.order_id
    WHERE O.order_status = 'delivered'
      AND O.order_delivered_customer_date IS NOT NULL
)
SELECT
    CASE
        WHEN days_late <= -8 THEN 'a. 8+ days early'
        WHEN days_late <   0 THEN 'b. 1-7 days early'
        WHEN days_late =   0 THEN 'c. on the estimated day'
        WHEN days_late <=  7 THEN 'd. 1-7 days late'
        ELSE                      'e. 8+ days late'
    END AS delivery_timing,
    COUNT(*)                    AS orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    -- FILTER is the clean way to count a subset inside an aggregate,
    -- instead of SUM(CASE WHEN ... THEN 1 ELSE 0 END).
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score = 1) / COUNT(*), 1) AS pct_one_star
FROM delivered
GROUP BY 1
ORDER BY 1;


-- results

--      delivery_timing     | orders | avg_review_score | pct_one_star
-- -------------------------+--------+------------------+--------------
--  a. 8+ days early        |  70935 |             4.32 |          6.5 ~4,611
--  b. 1-7 days early       |  17235 |             4.20 |          7.1 ~1,224
--  c. on the estimated day |   1280 |             4.03 |          8.5 ~109
--  d. 1-7 days late        |   3600 |             2.71 |         41.4 ~1,490
--  e. 8+ days late         |   2781 |             1.70 |         69.8 ~1,941
-- (5 rows)


-- interpretation

-- Lateness is the single sharpest driver of a bad review in this dataset. Being
-- early barely helps -- the score only creeps from 4.03 to 4.32 across the
-- whole early range -- but crossing the promised date is a cliff: the average
-- drops from 4.03 to 2.71 the moment an order is one day late, and to 1.70 once
-- it is more than a week late. The 1-star rate tells the same story even more
-- bluntly: 8.5% on the promised day, 41.4% when late, 69.8% when very late.
-- Practically, Olist gains almost nothing from beating its own estimate and
-- loses a great deal from missing it, so the estimated date is better set
-- conservatively than optimistically.
