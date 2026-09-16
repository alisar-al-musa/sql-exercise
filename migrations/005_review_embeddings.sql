-- 005: The vector column on order reviews.
--
-- Kept separate from 004 because it is a different concern: 004 declares what
-- the relational model guarantees, this prepares for semantic search over
-- review text. If the column later gains an index or changes dimension, the
-- history of that lives in its own lane.
--
-- The column is added and left EMPTY. Populating it needs an embedding model,
-- which is outside this pipeline; every row stays NULL until then.


-- 1024 dimensions, matching the model the brief specifies. The type comes from
-- pgvector, enabled in 001 -- which is why the image is pgvector/pgvector:pg18
-- and not the stock postgres image, where CREATE EXTENSION vector fails.
--
-- Nullable by necessity: 98,672 rows already exist, so a NOT NULL column with
-- no default could not be added at all. NULL here means "not embedded yet",
-- which is honest.
ALTER TABLE core.order_reviews
  ADD COLUMN IF NOT EXISTS embedding vector(1024);

COMMENT ON COLUMN core.order_reviews.embedding IS
  'Sentence embedding of review_comment_message, 1024-dim. Populated outside '
  'this pipeline; NULL means not yet embedded. 58,247 reviews have no message '
  'at all and will stay NULL permanently.';

-- No vector index is created here, on purpose. An ivfflat index builds its
-- lists by clustering the rows that exist at CREATE INDEX time, so building it
-- on zero rows produces an index that degrades to a sequential scan and has to
-- be dropped and rebuilt after loading. hnsw would tolerate an empty table but
-- would still slow every future insert for no benefit.
--
-- Once embeddings are populated, add one sized to the data, for example:
--
--   CREATE INDEX order_reviews_embedding_idx ON core.order_reviews
--     USING hnsw (embedding vector_cosine_ops);
--
-- Match the operator class to the distance operator the queries use:
-- vector_cosine_ops for <=>, vector_l2_ops for <->, vector_ip_ops for <#>.
-- An index built for one is not used by the others.
