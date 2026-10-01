

-- Generate embeddings for a small sample of review text 
-- Populate the embedding column added in Phase 2, then run a single nearest-neighbor query.


\set seed_order '00010242fe8c5a6d1ba2dd792cb16214'

SELECT r.review_id, r.review_comment_message
FROM core.order_reviews r
ORDER BY embedding <=> (SELECT embedding FROM core.order_reviews
                        WHERE order_id = :'seed_order')
LIMIT 5;



--            review_id             |                           review_comment_message                            
-- ----------------------------------+-----------------------------------------------------------------------------
--  97ca439bc427b48bc1cd7177abe71365 | Perfeito, produto entregue antes do combinado.
--  7a9bcceab85da70a4b7d4676cf895010 | Exatamente o produto que eu queria, entregue antes do prazo.
--  bf2f1411251c3f9acefbaa3be4df3ab1 | Produto entregue antes do prazo.
--  3ed9d0f8d46515973f1118eb6d85983c | O produto foi entregue antes do prazo. Ótima compra
--  d74c41005aac6736c5c6582001800e9f | Otimo atendimento, produto entregue bem antes do prazo estipulado, mto bom.
-- (5 rows)