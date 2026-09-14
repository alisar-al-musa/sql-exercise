-- 001: Enable required extensions.
-- pgvector powers the embedding column added to order_reviews in Phase 2.
-- It is enabled now so the extension is proven working before we depend on it.

CREATE EXTENSION IF NOT EXISTS vector;
