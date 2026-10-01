
-- 4. Average review score per product category, sorted worst to best,
--    excluding categories with fewer than 20 reviews.

-- One review belongs to an ORDER, not to an item. Joining reviews straight to
-- order_items counts the same review once per line, so an order with 3 items
-- of one category votes 3 times. 
-- we need to collapse to distinct (order, category) first.

WITH order_category AS (
    SELECT DISTINCT i.order_id, p.product_category_name_english AS category
    FROM core.order_items AS i
    JOIN core.products  AS p ON p.product_id = i.product_id
    -- 610 products have no category; they cannot be attributed, so drop them.
    WHERE p.product_category_name_english IS NOT NULL
)
SELECT oc.category,
       ROUND(AVG(r.review_score), 2) AS avg_score,
       COUNT(*)                      AS reviews
FROM order_category      AS oc
JOIN core.order_reviews  AS r ON r.order_id = oc.order_id
GROUP BY oc.category
-- HAVING, not WHERE: the filter is on an aggregate, computed after grouping.
HAVING COUNT(*) >= 20
ORDER BY avg_score ASC, reviews DESC;




-- my version: missed the idea of CTE: so it contains duplicates of reviews per category
-- SELECT P.product_category_name AS prod_name, AVG(R.review_score) AS avg_score, COUNT(*) AS num_reviews
-- FROM core.orders_reviews AS R 
-- JOIN core.order_items AS I ON I.order_id = R.order_id 
-- JOIN core.products AS P ON P.product_id = I.product_id
-- GROUP BY P.product_category_name
-- HAVING COUNT(*) >= 20
-- ORDER BY avg_score ASC



-- result 
--                 category                 | avg_score | reviews 
-- -----------------------------------------+-----------+---------
--  office_furniture                        |      3.62 |    1263
--  fashio_female_clothing                  |      3.69 |      39
--  fashion_male_clothing                   |      3.70 |     111
--  diapers_and_hygiene                     |      3.74 |      27
--  furniture_mattress_and_upholstery       |      3.82 |      38
--  home_comfort_2                          |      3.83 |      23
--  audio                                   |      3.84 |     347
--  construction_tools_safety               |      3.85 |     166
--  home_confort                            |      3.86 |     395
--  fixed_telephony                         |      3.90 |     214
--  fashion_underwear_beach                 |      3.93 |     120
--  bed_bath_table                          |      3.97 |    9313
--  home_construction                       |      3.97 |     487
--  telephony                               |      4.00 |    4168
--  party_supplies                          |      4.00 |      39
--  furniture_decor                         |      4.01 |    6398
--  agro_industry_and_commerce              |      4.02 |     182
--  computers_accessories                   |      4.03 |    6649
--  furniture_living_room                   |      4.03 |     417
--  market_place                            |      4.03 |     278
--  air_conditioning                        |      4.03 |     249
--  art                                     |      4.03 |     200
--  baby                                    |      4.04 |    2861
--  kitchen_dining_laundry_garden_furniture |      4.04 |     246
--  christmas_supplies                      |      4.06 |     126
--  watches_gifts                           |      4.07 |    5576
--  consoles_games                          |      4.07 |    1052
--  construction_tools_construction         |      4.08 |     743
--  auto                                    |      4.09 |    3877
--  dvds_blu_ray                            |      4.09 |      58
--  electronics                             |      4.10 |    2531
--  signaling_and_security                  |      4.11 |     138
--  construction_tools_lights               |      4.12 |     241
--  home_appliances_2                       |      4.13 |     232
--  housewares                              |      4.14 |    5843
--  garden_tools                            |      4.14 |    3496
--  furniture_bedroom                       |      4.14 |      95
--  home_appliances                         |      4.16 |     761
--  drinks                                  |      4.16 |     296
--  tablets_printing_image                  |      4.16 |      77
--  sports_leisure                          |      4.17 |    7668
--  cool_stuff                              |      4.17 |    3599
--  small_appliances                        |      4.17 |     624
--  computers                               |      4.17 |     178
--  arts_and_craftmanship                   |      4.17 |      23
--  health_beauty                           |      4.18 |    8771
--  musical_instruments                     |      4.18 |     622
--  toys                                    |      4.19 |    3853
--  fashion_bags_accessories                |      4.19 |    1854
--  industry_commerce_and_business          |      4.19 |     233
--  costruction_tools_garden                |      4.19 |     194
--  perfumery                               |      4.20 |    3150
--  fashion_shoes                           |      4.21 |     236
--  music                                   |      4.21 |      38
--  cine_photo                              |      4.23 |      65
--  pet_shop                                |      4.24 |    1701
--  stationery                              |      4.25 |    2295
--  fashion_sport                           |      4.26 |      27
--  food                                    |      4.28 |     445
--  small_appliances_home_oven_and_coffee   |      4.29 |      75
--  books_imported                          |      4.32 |      53
--  luggage_accessories                     |      4.33 |    1030
--  food_drink                              |      4.38 |     226
--  flowers                                 |      4.39 |      28
--  books_technical                         |      4.40 |     257
--  costruction_tools_tools                 |      4.43 |      94
--  books_general_interest                  |      4.46 |     508
-- (67 rows)
