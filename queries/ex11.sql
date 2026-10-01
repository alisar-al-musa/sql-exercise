

-- 11.  Checkpoint Q2: Which sellers are most at risk of falling out of the
--      top 10 by revenue (i.e. close behind the current #10)?

-- Revenue per seller = SUM(order_items.price), same measure as ex5.

-- The question has two sides, so the query shows the band around the cut line:
--   ranks 8-10  = inside the top 10, but only just -- these can be pushed out
--   ranks 11-15 = the challengers close behind #10
-- gap_to_10th is signed: negative = still above #10, positive = below it.

WITH seller_revenue AS (
    SELECT I.seller_id, SUM(I.price) AS revenue
    FROM core.order_items AS I
    JOIN core.orders AS O ON O.order_id = I.order_id
    WHERE O.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY I.seller_id
),
ranked AS (
    SELECT seller_id, revenue,
           RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
    FROM seller_revenue
),
cut_line AS (          -- one row: the revenue of the current #10
    SELECT revenue AS tenth_revenue
    FROM ranked
    WHERE revenue_rank = 10
)
SELECT R.revenue_rank,
       R.seller_id,
       S.seller_state,
       R.revenue,
       C.tenth_revenue - R.revenue AS gap_to_10th,
       ROUND(100.0 * (C.tenth_revenue - R.revenue) / C.tenth_revenue, 1) AS gap_pct
FROM ranked AS R
CROSS JOIN cut_line AS C
JOIN core.sellers AS S ON S.seller_id = R.seller_id
WHERE R.revenue_rank BETWEEN 8 AND 15
ORDER BY R.revenue_rank;


-- results

--  revenue_rank |            seller_id             | seller_state |  revenue  | gap_to_10th | gap_pct
-- --------------+----------------------------------+--------------+-----------+-------------+---------
--             8 | 7a67c85e85bb2ce8582c35f2203ad736 | SP           | 141715.54 |    -6555.84 |    -4.9
--             9 | 1025f0e2d44d7041d6cf58b6550e0bfa | SP           | 138968.55 |    -3808.85 |    -2.8
--            10 | 955fee9216a65b617aa5c0531780ce60 | SP           | 135159.70 |        0.00 |     0.0
--            11 | 46dc3b2cc0980fb8ec44634e21d2718e | RJ           | 127161.22 |     7998.48 |     5.9
--            12 | 6560211a19b47992c3666cc44a7e94c0 | SP           | 122776.83 |    12382.87 |     9.2
--            13 | 620c87c171fb2a6dd6e8bb4dec959fc6 | RJ           | 113659.40 |    21500.30 |    15.9
--            14 | 7d13fca15225358621be4086e1eb0964 | SP           | 113628.97 |    21530.73 |    15.9
--            15 | 5dceca129747e92ff8ef7a997dc4f8ca | SP           | 112085.63 |    23074.07 |    17.1
-- (8 rows)


-- interpretation

-- The bottom of the top 10 is crowded: ranks 8, 9 and 10 sit within R$6.6k of
-- each other, under 5% apart, so a single good month by a challenger reorders
-- them. Seller 955fee92... at #10 is the one actually at risk -- it holds the
-- last slot by R$8.0k (5.9%) over 46dc3b2c... at #11, which is the closest
-- threat. After rank 12 the gap widens past 15%, so realistically only two
-- sellers, #11 and #12, are near enough to break into the top 10 soon.
