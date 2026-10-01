#!/usr/bin/env python3
"""Populate core.order_reviews.embedding for a small sample of reviews.

Phase 5.5 of the brief: prove the vector pipeline works end to end. This is
NOT the RAG track -- it embeds a sample, nothing more.

    python scripts/embed_reviews.py            # default: 500 reviews
    python scripts/embed_reviews.py --limit 50

Re-runnable: it only ever picks rows whose embedding IS NULL, so running it
twice does not re-pay for work already done.

Standard library only. The database is reached through the same
`docker compose exec psql` path as scripts/query.ps1, so there is no driver to
install; Cohere is called over plain HTTPS with urllib.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

# Cohere's documented maximum texts per embed call.
BATCH_SIZE = 96

# embed-multilingual-v3.0, not the english model: the reviews are Portuguese.
# It returns exactly 1024 dimensions, which is what migration 005 declared the
# column as. Changing the model means changing the column.
MODEL = "embed-multilingual-v3.0"
EXPECTED_DIMS = 1024

# Stored text is a "document"; the thing you later search WITH is a "query".
# Cohere embeds the two differently, so this must match how the vector is used.
INPUT_TYPE = "search_document"

ENDPOINT = "https://api.cohere.com/v2/embed"


def load_env(path=".env"):
    """Read .env into a dict. Same format the shell and PowerShell runners use."""
    cfg = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            cfg[key.strip()] = value.strip()
    return cfg


def psql(cfg, sql, capture=True):
    """Run SQL in the db container and return stdout."""
    cmd = [
        "docker", "compose", "exec", "-T",
        "-e", f"PGPASSWORD={cfg['POSTGRES_PASSWORD']}",
        "db", "psql",
        "-v", "ON_ERROR_STOP=1",
        "-U", cfg["POSTGRES_USER"],
        "-d", cfg["POSTGRES_DB"],
        "-t", "-A",          # tuples only, unaligned: clean machine-readable output
    ]
    done = subprocess.run(cmd, input=sql, capture_output=True, text=True, encoding="utf-8")
    if done.returncode != 0:
        sys.exit(f"psql failed:\n{done.stderr}")
    return done.stdout.strip() if capture else ""


def fetch_sample(cfg, limit):
    """Pick reviews that have text and no embedding yet.

    Returned as one JSON blob rather than rows: review text contains newlines,
    tabs and quotes, so line-based parsing would mangle it.
    """
    sql = f"""
        SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
        FROM (
            SELECT order_id, review_comment_message AS msg
            FROM core.order_reviews
            WHERE review_comment_message IS NOT NULL
              AND length(review_comment_message) >= 20   -- skip "ok", "bom"
              AND embedding IS NULL
            ORDER BY order_id                            -- deterministic sample
            LIMIT {int(limit)}
        ) AS t;
    """
    return json.loads(psql(cfg, sql))


def embed(api_key, texts):
    """One Cohere embed call. Returns a list of 1024-float lists."""
    body = json.dumps({
        "model": MODEL,
        "texts": texts,
        "input_type": INPUT_TYPE,
        "embedding_types": ["float"],
    }).encode("utf-8")

    req = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = json.load(resp)
    except urllib.error.HTTPError as err:
        sys.exit(f"Cohere returned {err.code}: {err.read().decode('utf-8', 'replace')}")

    return payload["embeddings"]["float"]


def write_back(cfg, rows):
    """UPDATE the embeddings in one statement.

    A single UPDATE ... FROM (VALUES ...) is one round trip and one
    transaction, so a failure halfway leaves nothing half-written.
    """
    values = ",\n".join(
        "('{}','[{}]')".format(order_id, ",".join(f"{x:.6f}" for x in vec))
        for order_id, vec in rows
    )
    sql = f"""
        UPDATE core.order_reviews AS r
        SET embedding = v.emb::vector
        FROM (VALUES
        {values}
        ) AS v(order_id, emb)
        WHERE r.order_id = v.order_id;
    """
    psql(cfg, sql, capture=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=500,
                        help="how many reviews to embed (default 500)")
    args = parser.parse_args()

    cfg = load_env()
    cfg.update({k: v for k, v in os.environ.items() if k.startswith("COHERE")})

    api_key = cfg.get("COHERE_API_KEY")
    if not api_key:
        sys.exit("COHERE_API_KEY missing from .env -- get one at dashboard.cohere.com")

    sample = fetch_sample(cfg, args.limit)
    if not sample:
        print("Nothing to do: every sampled review already has an embedding.")
        return
    print(f"Embedding {len(sample)} reviews with {MODEL} ...")

    done = 0
    for start in range(0, len(sample), BATCH_SIZE):
        batch = sample[start:start + BATCH_SIZE]
        vectors = embed(api_key, [r["msg"] for r in batch])

        # Fail loudly on a dimension mismatch rather than letting Postgres
        # reject the cast with a less obvious error.
        if len(vectors[0]) != EXPECTED_DIMS:
            sys.exit(f"model returned {len(vectors[0])} dims, column expects {EXPECTED_DIMS}")

        write_back(cfg, [(r["order_id"], v) for r, v in zip(batch, vectors)])
        done += len(batch)
        print(f"  {done}/{len(sample)}")

    total = psql(cfg, "SELECT COUNT(embedding) FROM core.order_reviews;")
    print(f"Done. {total} reviews now have an embedding.")


if __name__ == "__main__":
    main()
