

-- 7.	Find the top 3 best-selling products within each category (not overall).

-- Best-selling = units sold, i.e. how many order_items lines the product appears on.

WITH product_sales AS (
    SELECT p.product_category_name_english AS category,
           i.product_id,
           COUNT(*) AS sold_count,
           -- Number the products inside each category, best seller first.
           ROW_NUMBER() OVER (PARTITION BY p.product_category_name_english
                              ORDER BY COUNT(*) DESC) AS rn
    FROM core.order_items AS i
    JOIN core.products    AS p ON p.product_id = i.product_id
    WHERE p.product_category_name_english IS NOT NULL
    GROUP BY 1, 2
)
-- The filter must be out here: rn does not exist yet inside the CTE's WHERE.
SELECT category, product_id, sold_count
FROM product_sales
WHERE rn <= 3
ORDER BY category, rn;

-- Used ROW_NUMBER() since RANK and RANK_DENSE gives same number at tie, here we need exactly the first 3 rows


-- -- answer:

--                    category                    |            product_id            | sold_count 
-- -----------------------------------------------+----------------------------------+------------
--  agro_industry_and_commerce                    | 11250b0d4b709fee92441c5f34122aed |         22
--  agro_industry_and_commerce                    | 423a6644f0aa529e8828ff1f91003690 |         18
--  agro_industry_and_commerce                    | 672e757f331900b9deea127a2a7b79fd |         17
--  air_conditioning                              | 98e91d0f32954dcd8505875bb2b42cdb |         17
--  air_conditioning                              | ccb162ed569f47d83f62aebd5700d7ad |         13
--  air_conditioning                              | 0e34187d4312b97b5e698836d28ed040 |         11
--  art                                           | 4fe644d766c7566dbc46fb851363cb3b |        107
--  art                                           | 986700c98805af229ab7ad51b95fa356 |          7
--  art                                           | bf359473d58e90d8fc29bf8f3d282ea9 |          7
--  arts_and_craftmanship                         | b9976e9c22fb1540bd71d1bcd2989475 |          5
--  arts_and_craftmanship                         | 43f224fb79bae5b22585eb868fe3b84b |          2
--  arts_and_craftmanship                         | 3a96bcbf644a5d390107570628568026 |          1
--  audio                                         | db5efde3ad0cc579b130d71c4b2db522 |         48
--  audio                                         | a59fb60fddcc72a9878b7ed5cb69d8e4 |         45
--  audio                                         | 7c4a8bec217df1de0df2b5aaf8175b65 |         40
--  auto                                          | 4fcb3d9a5f4871e8362dfedbdb02b064 |         89
--  auto                                          | a50acd33ba7a8da8e9db65094fa990a4 |         84
--  auto                                          | 629e019a6f298a83aeecc7877964f935 |         74
--  baby                                          | cac9e5692471a0700418aa3400b9b2b1 |         89
--  baby                                          | ea44caac707f7f1325182a538007f838 |         63
--  baby                                          | 8aa6223e400af9c97b07c75993142721 |         48
--  bed_bath_table                                | 99a4788cb24856965c36a24e339b6058 |        488
--  bed_bath_table                                | f1c7f353075ce59d8a6f3cf58f419c9c |        154
--  bed_bath_table                                | 06edb72f1e0c64b14c5b79353f7abea3 |        143
--  books_general_interest                        | f35927953ed82e19d06ad3aac2f06353 |         58
--  books_general_interest                        | 9d0bb30eed80184666c8acad23921283 |         19
--  books_general_interest                        | 1cc61b32763a4d816212b3507b6b6c59 |         11
--  books_imported                                | 68ad45d48d69404aeb71ce87e1b2c948 |          8
--  books_imported                                | 98d893a81a1845b6f278f33eee0a4f36 |          7
--  books_imported                                | 82d7b276f49e72ffce78d10b20518808 |          7
--  books_technical                               | 173e9fe34bfe97f3a5e6dc57fe897b74 |         43
--  books_technical                               | edd087ed331c3ce178ec3489b9ecf117 |          8
--  books_technical                               | 08bcc2d85da3a9c0e2ac1cc28b67418d |          7
--  cds_dvds_musicals                             | 1dceebcc5f23c02ea23e16d5bedca000 |         14
--  christmas_supplies                            | 40e8b425d1a26e2d9cb77363523e05ce |         22
--  christmas_supplies                            | f59871b3d9da4c64cbe41ad3dd04dc14 |         10
--  christmas_supplies                            | f3ccdb9f9c7f31e0efd626e9110b85f5 |          9
--  cine_photo                                    | e988092a8afe5d9393a5c3a7ca17691c |         12
--  cine_photo                                    | c3798d484fb730f0b5c23af0d5361595 |         10
--  cine_photo                                    | 1f5f0f003ce8595ad88fb215ec1409e6 |         10
--  computers                                     | d6160fb7873f184099d9bc95e30376af |         35
--  computers                                     | a04087ab6a96ffa041f8a2701a72b616 |         25
--  computers                                     | 588531f8ec37e7d5ff5b7b22ea0488f8 |         20
--  computers_accessories                         | d1c427060a0f73f6b889a5c7c61f2ac4 |        343
--  computers_accessories                         | 3dd2a17168ec895c781a9191c1e95ad7 |        274
--  computers_accessories                         | e53e557d5a159f5aa2c5e995dfdf244b |        183



