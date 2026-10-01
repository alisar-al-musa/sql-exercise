
-- 2.	Find every product that has never been ordered.

-- use NOT IN
SELECT P.product_id 
FROM  core.products AS P 
-- Get every product whose ID is not among the product IDs that are in order_items.
WHERE P.product_id NOT IN (
    SELECT O.product_id
    FROM  core.order_items AS O
);


-- 2 b: use NOT EXISTS
SELECT P.product_id 
FROM  core.products AS P 
-- it means: keep the product only if no matching row exists in order_items.
WHERE NOT EXISTS (
    SELECT * 
    FROM core.order_items AS O
    WHERE O.product_id = P.product_id
);


-- 2c: use LEFT join
SELECT P.product_id
FROM core.products AS P
LEFT JOIN core.order_items AS I ON I.product_id = P.product_id
-- among those joined, give me only the product ids that have NULL from the right side.
WHERE I.order_id IS NULL