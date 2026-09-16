# Entity relationship diagram — `core`

The working schema after Phase 2. Written as Mermaid so it diffs in git and
renders on GitHub without a binary image drifting out of sync with the SQL.

The authority is [`migrations/004_keys_and_indexes.sql`](../migrations/004_keys_and_indexes.sql);
this diagram is a reading of it. Row counts are the seeded values.

```mermaid
erDiagram
    CUSTOMERS ||--|| ORDERS : "places (1:1, see note)"
    ORDERS    ||--o{ ORDER_ITEMS : "contains"
    ORDERS    ||--o{ PAYMENTS : "paid by"
    ORDERS    ||--o| ORDER_REVIEWS : "reviewed by"
    PRODUCTS  ||--o{ ORDER_ITEMS : "sold as"
    SELLERS   ||--o{ ORDER_ITEMS : "fulfils"

    PRODUCTS   }o..o| PRODUCT_CATEGORY_TRANSLATION : "LEFT JOIN, not an FK"
    CUSTOMERS  }o..o{ GEOLOCATION : "LEFT JOIN, not an FK"
    SELLERS    }o..o{ GEOLOCATION : "LEFT JOIN, not an FK"

    CUSTOMERS {
        text    customer_id              PK "one per ORDER, not per person"
        text    customer_unique_id          "the actual person; 96,096 distinct"
        integer customer_zip_code_prefix
        text    customer_city
        text    customer_state
    }

    ORDERS {
        text      order_id                      PK
        text      customer_id                   FK "UNIQUE -- hence 1:1"
        text      order_status                     "8 known values, CHECKed"
        timestamp order_purchase_timestamp         "indexed"
        timestamp order_approved_at                "nullable"
        timestamp order_delivered_carrier_date     "nullable"
        timestamp order_delivered_customer_date    "nullable; 2,957 NULL"
        date      order_estimated_delivery_date    "DATE: no value carries a time"
    }

    ORDER_ITEMS {
        text          order_id            PK "FK"
        integer       order_item_id       PK "line number 1-21, not an id"
        text          product_id          FK "indexed"
        text          seller_id           FK "indexed"
        timestamp     shipping_limit_date
        numeric       price
        numeric       freight_value
    }

    PAYMENTS {
        text          order_id             PK "FK"
        integer       payment_sequential   PK "splits one order across rows"
        text          payment_type            "5 known values, CHECKed"
        integer       payment_installments
        numeric       payment_value
    }

    ORDER_REVIEWS {
        text      order_id                PK "FK -- one review per order"
        text      review_id                  "NOT unique: 789 span several orders"
        integer   review_score               "CHECKed 1-5"
        text      review_comment_title       "nullable; 87,656 empty"
        text      review_comment_message     "nullable; 58,247 empty"
        timestamp review_creation_date
        timestamp review_answer_timestamp    "the de-duplication tie-break"
        vector    embedding                  "1024-dim, nullable, left empty"
    }

    PRODUCTS {
        text    product_id                    PK
        text    product_category_name            "nullable; 610 missing"
        text    product_category_name_english    "indexed; falls back to pt"
        integer product_name_length              "typo corrected from source"
        integer product_description_length
        integer product_photos_qty
        integer product_weight_g
        integer product_length_cm
        integer product_height_cm
        integer product_width_cm
    }

    SELLERS {
        text    seller_id             PK
        integer seller_zip_code_prefix
        text    seller_city
        text    seller_state
    }

    PRODUCT_CATEGORY_TRANSLATION {
        text product_category_name         PK "71 rows; 2 categories missing"
        text product_category_name_english
    }

    GEOLOCATION {
        integer geolocation_zip_code_prefix "indexed; NO primary key"
        numeric geolocation_lat
        numeric geolocation_lng
        text    geolocation_city
        text    geolocation_state
    }
```

## How to read the lines

Solid lines are declared foreign keys. Dashed lines are joins we perform but
the database does not enforce, because the data will not support a constraint.

| Relationship | Cardinality | Why |
| --- | --- | --- |
| `customers → orders` | **1:1** | `orders.customer_id` is `UNIQUE` |
| `orders → order_items` | 1:0..N | 775 orders have no items |
| `orders → payments` | 1:0..N | 1 order has no payment; split payments give several rows |
| `orders → order_reviews` | 1:0..1 | 768 orders have no review; duplicates removed in cleaning |
| `products → order_items` | 1:0..N | every product happens to be ordered at least once |
| `sellers → order_items` | 1:0..N | |

## The three relationships that are not foreign keys

| Join | Orphans | Why it cannot be enforced |
| --- | ---: | --- |
| `products.product_category_name → translation` | 13 products | 2 categories missing from the 71-row file |
| `customers.customer_zip_code_prefix → geolocation` | 157 zips | geolocation does not cover every zip in use |
| `sellers.seller_zip_code_prefix → geolocation` | 7 zips | same |

Declaring any of these would force us either to delete real rows or to invent
source data. They are `LEFT JOIN` lookups instead.

## The 1:1 that surprises people

`customers` is not a table of people. Olist issues a **fresh `customer_id` for
every order**, so the table is really an order-address snapshot: 99,440 rows,
one per order. The person is `customer_unique_id` — 96,096 distinct, averaging
1.035 orders each, with one person placing 17.

Two consequences for Phase 3:

- `count(DISTINCT customer_id)` counts **orders**, not people. Use
  `count(DISTINCT customer_unique_id)` for people.
- The address belongs to the order, not the person: 250 people used more than
  one zip code across their orders, 122 more than one city, and 39 more than
  one state. Collapsing `customers` down to one row per person would silently
  discard those addresses, which is why the table keeps its per-order shape.

## What has no primary key, and why

`geolocation` has none. No column or combination is unique even after
whole-row de-duplication (1,000,163 → 738,332), and nothing references an
individual row. It is a coordinate lookup, not an entity. A surrogate identity
column would invent a key nothing would ever use.
