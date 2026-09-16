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

The two cases get opposite treatment, because they are opposite problems.

**Decision — the 547 duplicated orders: de-duplicate to one review per order.**
An order logically has one review; these are data errors, not a real
one-to-many relationship. `order_id` becomes the primary key.

The tie-break matters, because the duplicates often disagree:

| | Orders | Avg score gap | Worst |
| --- | ---: | ---: | ---: |
| Identical score | 345 | 0 | 0 |
| **Conflicting scores** | **202** | **2.04** | **4** |

The pattern in the conflicts is a customer rating optimistically, then returning
to rate again once the order actually arrived — or did not:

```
09a38776c4... | 5 | created 2018-02-17 | (no comment)
09a38776c4... | 1 | created 2018-03-07 | "nao recebi o produto"   -- "I did not receive the product"
```

So we keep the **latest** review, which is the customer's settled verdict.
Ordering by `review_answer_timestamp` resolves all 547; `review_creation_date`
leaves 157 tied. 547 rows dropped, **98,673 remain**.

**Decision — the 789 duplicated review_ids: keep every row.** These are one
person's review attached to several of their orders, which is legitimate.
The consequence is that `review_id` cannot be a primary key or carry a `UNIQUE`
constraint; it is a plain attribute recording which review text a row came from.

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

Measured from the 96,469 delivered orders that have both dates, carrier handover
to customer takes a **median of 7.1 days** (mean 9.33, and 23 orders have a
negative gap — more source noise).

**Decision — the 7 with a carrier date: impute
`order_delivered_carrier_date + 7.1 days`.** The carrier date alone is a lower
bound, not an estimate; using it raw would assert a zero-day delivery and pull
every one of these to the earliest possible date. Adding the median gap keeps
the ordering constraint (delivery cannot precede handover) without that bias.

**Decision — the 1 with neither date: delete the order,** along with its 1
`order_items`, 1 payment and 1 review row. Nothing in the source supports an
estimate for it. The child rows have to go too, or Phase 2's foreign keys fail.

Dropping all 8 was considered and rejected: it would orphan 24 child rows and
remove **R$1,249.18** of revenue, destroying real order, payment and review data
to fix a missing date.

Imputed values are **not flagged with a column** — this note is the record of
which rows were changed. All 7 fall on time against their estimated dates either
way, so the imputation does not alter any late-delivery result.

The remaining 2,957 nulls stay `NULL` and the columns stay nullable, so a
late-delivery query must still filter on `order_delivered_customer_date IS NOT
NULL` rather than trusting `order_status = 'delivered'`.

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
| `products.product_category_name → translation` | **13 products** |
| `customers.customer_zip_code_prefix → geolocation` | **157 zips** |
| `sellers.seller_zip_code_prefix → geolocation` | **7 zips** |

Six of the nine hold and were declared as real foreign keys in Phase 2. The
bottom three could not be.

**The 13 orphans:** `portateis_cozinha_e_preparadores_de_alimentos` (10 products)
and `pc_gamer` (3). Both are missing from the 71-row translation file.

**Decision:** treat the translation table as a **lookup, joined with LEFT JOIN**,
not as a foreign-key parent. Untranslated categories fall back to the Portuguese
name via `COALESCE`. Adding the two missing rows ourselves would mean inventing
source data; enforcing the FK would mean deleting 13 real products.

**The geolocation orphans:** `geolocation` does not cover every zip prefix in
use — 157 customer prefixes and 7 seller prefixes are absent from it.

**Decision:** `geolocation` is a **lookup, always LEFT JOINed**, never a
foreign-key parent. It also gets no primary key: no column or combination is
unique even after de-duplication, and nothing references an individual row.
Any query mapping an order to coordinates must expect misses.

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

## 7. Two structural notes

**`orders` → `customers` is 1:1, not many-to-1.** `orders.customer_id` has
99,441 distinct values in 99,441 rows — unique. Olist mints a fresh
`customer_id` for every order, so `customers` is really an order-address
snapshot rather than a customer table. The person is `customer_unique_id`:
96,096 distinct, **1.035 orders each**. So `count(DISTINCT customer_id)` counts
orders, not people, and any "customers" figure must say which it means.

**`order_estimated_delivery_date` is a date, not a timestamp.** Every one of its
99,441 values is exactly midnight, so it becomes `DATE`; `TIMESTAMP` would imply
precision the source does not have. This matters for Exercise 5.1: a real
delivery timestamp compared against a midnight estimate counts anything after
00:00 on the estimated day as late. `review_creation_date` looks similar but 85
of its rows do carry a time, so it stays `TIMESTAMP`.


## 8. Constraint candidates, tested before declaring

Every `CHECK` proposed for Phase 2 was counted against the loaded rows first.
Roughly a third of the obvious-looking ones turned out to be false.

**Declared** — zero violations, so they hold:

| Constraint | Observed |
| --- | --- |
| `review_score BETWEEN 1 AND 5` | range is exactly 1–5 |
| `price >= 0`, `freight_value >= 0`, `payment_value >= 0` | minimums 0.85, 0.00, 0.00 |
| `order_item_id >= 1`, `payment_sequential >= 1` | both start at 1 |
| `payment_installments >= 0` | minimum 0 |
| `order_approved_at >= order_purchase_timestamp` | 0 violations |
| `review_answer_timestamp >= review_creation_date` | 0 violations |
| latitude ±90, longitude ±180 | 0 violations |
| `order_status` in 8 values, `payment_type` in 5 | closed sets in the source |

**Rejected** — the data violates them, so declaring any would fail the
migration:

| Candidate | Violating rows |
| --- | ---: |
| `order_delivered_carrier_date >= order_purchase_timestamp` | **166** |
| `order_delivered_customer_date >= order_delivered_carrier_date` | **23** |
| `product_weight_g > 0` | **4** |
| coordinates inside a Brazilian bounding box | **33** |

Note the second one: cleaning rule 2 imputes delivery as `carrier + 7.1 days`
precisely so delivery follows handover, yet 23 *other* rows already breach that
ordering in the source. Fixing the eight contradictions did not make the rule
universally true.

**Decision:** declare only what holds. The alternative — deleting 193 real rows
so an invented constraint can be satisfied — would destroy more information
than it protects. `>= 0` was chosen over `> 0` for money for the same reason:
free-shipping lines legitimately cost 0.00, and requiring a positive amount
would be a business rule we made up rather than something the data states.

## 9. Addresses belong to the order, not the person

Tested while deciding whether `customers` could collapse to one row per person:

| | Count |
| --- | ---: |
| Distinct people (`customer_unique_id`) | 96,096 |
| …using more than one zip code | **250** |
| …more than one city | 122 |
| …more than one state | **39** |
| Most orders by one person | 17 |

So the repetition in `customers` is **not redundancy** — it is per-order data.
Collapsing to `customer_unique_id` would silently discard 250 real shipping
addresses.

**Decision:** keep `customers` keyed on `customer_id`, one row per order, with
the address alongside it. `customer_unique_id` stays an indexed attribute for
counting real people. Restructuring so that `customers` held only
`customer_unique_id` was considered and rejected: it would leave a table with a
single column, and move the address to `orders` for a gain that does not
justify diverging from the source shape.
