# Data profile — staging

Findings from profiling `staging.*` after ingestion, and the cleaning decisions
they drive. Every number here came from a query against the loaded data, not
from the dataset's documentation.

Re-run with `bash scripts/profile.sh`.

## 1. Key uniqueness

| Candidate key | Rows | Distinct | Usable as PK? |
| --- | ---: | ---: | --- |
| `orders.order_id` | 99,441 | 99,441 | yes |
| `customers.customer_id` | 99,441 | 99,441 | yes |
| `customers.customer_unique_id` | 99,441 | 96,096 | **no** — by design |
| `products.product_id` | 32,951 | 32,951 | yes |
| `sellers.seller_id` | 3,095 | 3,095 | yes |
| `order_items (order_id, order_item_id)` | 112,650 | 112,650 | yes, composite |
| `order_payments (order_id, payment_sequential)` | 103,886 | 103,886 | yes, composite |
| `order_reviews.review_id` | 99,224 | 98,410 | **no** |
| `order_reviews.order_id` | 99,224 | 98,673 | **no** |
| `order_reviews (review_id, order_id)` | 99,224 | 99,224 | yes, composite |

`customer_unique_id` is not a bug: Olist issues a fresh `customer_id` per order
and uses `customer_unique_id` to identify the actual person. 99,441 − 96,096 =
**3,345 repeat purchases**. Any "customers" count must say which one it means.

### The duplicates in `order_reviews`

Two separate problems, and they are not the same problem:

- **547 orders reviewed more than once** — 543 orders with 2 reviews, 4 with 3.
- **789 review_ids appearing more than once** — 764 twice, 25 three times.
  These rows carry **different `order_id`s** but identical score, comment and
  timestamps. It looks like one customer review written against a multi-order
  purchase, replicated per order.

No two rows are identical across all seven columns (99,224 distinct whole rows),
so blind `DISTINCT` de-duplication removes nothing.

**Decision:** keep every row. Use the composite `(review_id, order_id)` as the
primary key. Dropping rows would discard real review text needed by the RAG
track later, and picking a "winner" per order would be an arbitrary choice
disguised as cleaning. The consequence is that `orders → order_reviews` is
one-to-many, so any average-score query must aggregate rather than assume one
review per order.

## 2. Type casting

`pg_input_is_valid(value, type)` tests a cast without raising, so every non-null
value in every column was checked. **Zero failures** across all 13 typed
columns: 5 order timestamps, `shipping_limit_date`, `price`, `freight_value`,
`payment_value`, `review_score`, `product_weight_g`, `product_photos_qty`, and
1,000,163 geolocation latitudes.

**Decision:** cast directly during cleaning. No sanitising, no regex guards, no
error-quarantine table. The "dates as text" problem the brief anticipates is
purely an artefact of CSV having no types — the values themselves are clean.

Timestamps become `TIMESTAMP` (no timezone). The dataset is single-region
Brazilian local time with no offset information, so `TIMESTAMPTZ` would force us
to invent a timezone the source never stated.

## 3. Missing values

| Status | Orders | No approved_at | No carrier date | No delivery date |
| --- | ---: | ---: | ---: | ---: |
| delivered | 96,478 | 14 | 2 | **8** |
| shipped | 1,107 | 0 | 0 | 1,107 |
| canceled | 625 | 141 | 550 | 619 |
| unavailable | 609 | 0 | 609 | 609 |
| invoiced | 314 | 0 | 314 | 314 |
| processing | 301 | 0 | 301 | 301 |
| created | 5 | 5 | 5 | 5 |
| approved | 2 | 0 | 2 | 2 |

2,957 of the 2,965 missing delivery dates are explained by status — the order
was never delivered, so no date exists.

**Decision:** keep them `NULL` and leave the columns nullable. `NULL` means "did
not happen", which is exactly true here. Substituting a sentinel date would
silently corrupt every delivery-time calculation.

### The 8 contradictions

Eight orders are marked `delivered` with no `order_delivered_customer_date`.
Seven have a carrier date, so they did physically ship; one has neither.

**Decision:** keep them as-is, do not patch the status. They are genuine source
inconsistencies, and the LEFT JOIN + NULL handling they force is the point of
Exercise 5.1. Any late-delivery query must filter on
`order_delivered_customer_date IS NOT NULL` rather than trusting
`order_status = 'delivered'` — these 8 rows are what breaks the lazy version.

## 4. Referential integrity

Checked with anti-joins before declaring any constraint, because a failing
`ALTER TABLE ... ADD FOREIGN KEY` in Phase 2 is a much worse way to discover this.

| Foreign key | Orphans |
| --- | ---: |
| `orders.customer_id → customers` | 0 |
| `order_items.order_id → orders` | 0 |
| `order_items.product_id → products` | 0 |
| `order_items.seller_id → sellers` | 0 |
| `order_payments.order_id → orders` | 0 |
| `order_reviews.order_id → orders` | 0 |
| `products.product_category_name → translation` | **13** |

All Phase 2 foreign keys will hold except the category translation.

**The 13 orphans:** `portateis_cozinha_e_preparadores_de_alimentos` (10 products)
and `pc_gamer` (3). Both are missing from the 71-row translation file.

**Decision:** treat the translation table as a **lookup, joined with LEFT JOIN**,
not as a foreign-key parent. Untranslated categories fall back to the Portuguese
name via `COALESCE`. Adding the two missing rows ourselves would mean inventing
source data; enforcing the FK would mean deleting 13 real products.

## 5. Coverage gaps

Not errors, but they decide INNER vs LEFT JOIN in Phase 3.

| Gap | Count |
| --- | ---: |
| Orders with no `order_items` | 775 |
| Orders with no review | 768 |
| Orders with no payment | 1 |
| Products with `NULL` category | 610 |
| **Products never ordered** | **0** |

The 775 item-less orders are mostly `unavailable` and `canceled`. An INNER JOIN
from orders to order_items silently drops them — fine for revenue, wrong for
order counts.

**Products never ordered is genuinely 0.** All 32,951 products appear in
`order_items`. Exercise 5.1 asks for products never ordered, and the correct
answer for this dataset is an **empty result set**. An empty result there means
the query is right, not broken.

## 6. Encoding

`product_category_name_translation.csv` starts with a UTF-8 BOM and uses CRLF.
`COPY ... HEADER true` discards the header line unparsed, so the BOM never
reaches a value — verified by hex-dumping the first loaded category
(`62656c65...`, no `EFBBBF` prefix). Accented text round-trips correctly
(`são paulo`). Empty CSV fields became real `NULL`, not `''` — 2,965 vs 0.
