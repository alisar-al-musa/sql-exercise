
-- 5.	Rank sellers by total revenue, and show each seller's rank within their state.

SELECT  S.seller_id,
        S.seller_state, 
        SUM(I.price) AS total_revenue,
        RANK() OVER( ORDER BY SUM(I.price) DESC) AS overall_rank, 
        RANK() OVER(
                PARTITION BY S.seller_state
                ORDER BY SUM(I.price) DESC
                ) AS state_rank
FROM core.sellers AS S
JOIN core.order_items AS I ON I.seller_id = S.seller_id
GROUP BY S.seller_id, S.seller_state
ORDER BY overall_rank


-- result
--  c3e2398fcc7e581cda2e546557bf6968 | SP           |         14.90 |         3070 |       1833
--  a61cc04793308395a840807104365121 | SP           |         14.63 |         3073 |       1835
--  6576fd3e23c88f0e5d4d23f39bba0542 | SP           |         14.50 |         3074 |       1836
--  5b92bfa4120daa27c574daa2e386c693 | SP           |         14.00 |         3075 |       1837
--  fb503a924a0b9db19d83dd0ac6dbef8c | RS           |         13.90 |         3076 |        129
--  6614814a00d344b846ae209f95ee7e3f | SP           |         13.00 |         3077 |       1838
--  b5f0712d22a873b6797ab6cc65c3fcba | SP           |         12.99 |         3078 |       1839
--  c1dde11f12d05c478f5de2d7319ad3b2 | SP           |         12.50 |         3079 |       1840
--  9e25199f6ef7e7c347120ff175652c3b | SP           |         12.50 |         3079 |       1840
--  7ab0dd5487bab2dc835337b244f689fb | SP           |         12.50 |         3079 |       1840
--  3d62f86afa7c73be2628a3be1423f5a0 | SP           |         12.00 |         3082 |       1843
--  3ac588cd562971392504a9e17130c40b | SP           |         11.90 |         3083 |       1844
--  cc1f04647be106ba74e62b21f358af25 | SP           |         11.90 |         3083 |       1844
--  344223b2a90784f64136a8a5da012e7f | SC           |         10.90 |         3085 |        188
--  95cca791657aabeff15a07eb152d7841 | PR           |          9.99 |         3086 |        348
--  c18309219e789960add0b2255ca4b091 | RJ           |          9.90 |         3087 |        171
--  0f94588695d71662beec8d883ffacf09 | SC           |          9.00 |         3088 |        189
--  4965a7002cca77301c82d3f91b82e1a9 | SP           |          8.49 |         3089 |       1846
--  ad14615bdd492b01b0d97922e87cb87f | SC           |          8.25 |         3090 |        190
--  34aefe746cd81b7f3b23253ea28bef39 | PR           |          8.00 |         3091 |        349
--  702835e4b785b67a084280efca355756 | MG           |          7.60 |         3092 |        244
--  1fa2d3def6adfa70e58c276bb64fe5bb | SP           |          6.90 |         3093 |       1847
--  77128dec4bec4878c37ab7d6169d6f26 | SP           |          6.50 |         3094 |       1848
--  cf6f6bc4df3999b9c6440f124fb2f687 | SP           |          3.50 |         3095 |       1849
-- (3095 rows)
