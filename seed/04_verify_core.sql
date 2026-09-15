-- Verify the working schema.
--
-- Fails loudly rather than letting a wrong number reach a query three phases
-- later. Checks four things: row counts, that every key intended for Phase 2
-- is actually unique, that each cleaning rule did what it claims, and that the
-- foreign keys Phase 2 will declare would hold.

-- 1. Row counts -------------------------------------------------------------
DO $$
DECLARE
  expected CONSTANT TEXT[][] := ARRAY[
    ['customers',                    '99441'],
    ['geolocation',                  '738332'],
    ['sellers',                      '3095'],
    ['product_category_translation', '71'],
    ['products',                     '32951'],
    ['orders',                       '99440'],
    ['order_items',                  '112649'],
    ['payments',                     '103885'],
    ['order_reviews',                '98672']
  ];
  tbl TEXT; want BIGINT; got BIGINT; errors TEXT := '';
BEGIN
  FOR i IN 1 .. array_length(expected, 1) LOOP
    tbl := expected[i][1]; want := expected[i][2]::BIGINT;
    EXECUTE format('SELECT count(*) FROM core.%I', tbl) INTO got;
    IF got = want THEN
      RAISE NOTICE '  ok    core.% = %', rpad(tbl, 30), got;
    ELSE
      errors := errors || format(E'\n  core.%s: expected %s, got %s', tbl, want, got);
    END IF;
  END LOOP;
  IF errors <> '' THEN
    RAISE EXCEPTION 'core row counts are wrong:%', errors;
  END IF;
END $$;

-- 2. Keys intended for Phase 2 are unique ------------------------------------
DO $$
DECLARE
  keys CONSTANT TEXT[][] := ARRAY[
    ['customers',                    'customer_id'],
    ['sellers',                      'seller_id'],
    ['products',                     'product_id'],
    ['product_category_translation', 'product_category_name'],
    ['orders',                       'order_id'],
    -- Unique too: Olist mints one customer_id per order, so orders:customers
    -- is 1:1. Worth asserting so a future change that breaks it is caught.
    ['orders',                       'customer_id'],
    -- order_id alone, because cleaning reduced this to one review per order.
    ['order_reviews',                'order_id'],
    ['order_items',                  'order_id, order_item_id'],
    ['payments',                     'order_id, payment_sequential']
  ];
  tbl TEXT; col TEXT; dupes BIGINT; errors TEXT := '';
BEGIN
  FOR i IN 1 .. array_length(keys, 1) LOOP
    tbl := keys[i][1]; col := keys[i][2];
    EXECUTE format(
      'SELECT count(*) FROM (SELECT %s FROM core.%I GROUP BY %s HAVING count(*) > 1) d',
      col, tbl, col) INTO dupes;
    IF dupes = 0 THEN
      RAISE NOTICE '  ok    unique: core.%(%)', tbl, col;
    ELSE
      errors := errors || format(E'\n  core.%s(%s): %s duplicated values', tbl, col, dupes);
    END IF;
  END LOOP;
  IF errors <> '' THEN
    RAISE EXCEPTION 'keys are not unique:%', errors;
  END IF;
END $$;

-- 3. The cleaning rules did what they claim ----------------------------------
DO $$
DECLARE n BIGINT; errors TEXT := '';
BEGIN
  -- Rule 1: the dropped order and all three of its child rows are gone.
  SELECT count(*) INTO n FROM core.orders
   WHERE order_id = '2d858f451373b04fb5c984a1cc2defaf';
  IF n <> 0 THEN errors := errors || E'\n  the order with no dates was not dropped'; END IF;

  SELECT (SELECT count(*) FROM core.order_items   WHERE order_id = '2d858f451373b04fb5c984a1cc2defaf')
       + (SELECT count(*) FROM core.payments      WHERE order_id = '2d858f451373b04fb5c984a1cc2defaf')
       + (SELECT count(*) FROM core.order_reviews WHERE order_id = '2d858f451373b04fb5c984a1cc2defaf')
    INTO n;
  IF n <> 0 THEN errors := errors || format(E'\n  %s child rows of the dropped order survived', n); END IF;

  -- Rule 2: no delivered order is left without a delivery date.
  SELECT count(*) INTO n FROM core.orders
   WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;
  IF n <> 0 THEN errors := errors || format(E'\n  %s delivered orders still have no delivery date', n); END IF;

  -- ...and delivery never precedes carrier handover, which is what the
  -- imputation was designed to guarantee.
  SELECT count(*) INTO n FROM core.orders
   WHERE order_delivered_customer_date < order_delivered_carrier_date
     AND order_delivered_customer_date IS NOT NULL;
  IF n > 23 THEN
    errors := errors || format(E'\n  %s orders deliver before handover (23 are pre-existing source noise)', n);
  END IF;

  -- Rule 2 again: exactly seven orders were imputed.
  SELECT count(*) INTO n FROM core.orders o
   WHERE o.order_status = 'delivered'
     AND EXISTS (SELECT 1 FROM staging.orders s
                  WHERE s.order_id = o.order_id
                    AND s.order_delivered_customer_date IS NULL
                    AND s.order_delivered_carrier_date IS NOT NULL);
  IF n <> 7 THEN errors := errors || format(E'\n  expected 7 imputed delivery dates, found %s', n); END IF;

  -- Rule 3: the 2,957 genuinely-missing delivery dates were NOT filled in.
  SELECT count(*) INTO n FROM core.orders WHERE order_delivered_customer_date IS NULL;
  IF n <> 2957 THEN errors := errors || format(E'\n  expected 2957 remaining NULL delivery dates, found %s', n); END IF;

  -- Rule 4: every product kept a category name, including the 13 untranslated.
  SELECT count(*) INTO n FROM core.products
   WHERE product_category_name IS NOT NULL AND product_category_name_english IS NULL;
  IF n <> 0 THEN errors := errors || format(E'\n  %s products lost their category in translation', n); END IF;

  -- The 13 fallbacks must be found by absence from the translation table, not
  -- by comparing the two names: seven categories (audio, pet_shop, cool_stuff,
  -- consoles_games, market_place, la_cuisine, dvds_blu_ray) are the same word
  -- in both languages, so 2,058 products have matching names legitimately.
  SELECT count(*) INTO n FROM core.products p
   WHERE p.product_category_name IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM core.product_category_translation t
                     WHERE t.product_category_name = p.product_category_name);
  IF n <> 13 THEN errors := errors || format(E'\n  expected 13 products falling back to the Portuguese name, found %s', n); END IF;

  -- The typo is gone.
  SELECT count(*) INTO n FROM information_schema.columns
   WHERE table_schema = 'core' AND column_name LIKE '%lenght%';
  IF n <> 0 THEN errors := errors || E'\n  a column is still spelled "lenght"'; END IF;

  IF errors <> '' THEN
    RAISE EXCEPTION 'cleaning rules did not apply correctly:%', errors;
  END IF;
  RAISE NOTICE '  ok    all four cleaning rules verified';
END $$;

-- 4. The foreign keys Phase 2 will declare would hold ------------------------
DO $$
DECLARE n BIGINT; errors TEXT := '';
BEGIN
  SELECT count(*) INTO n FROM core.orders o
   WHERE NOT EXISTS (SELECT 1 FROM core.customers c WHERE c.customer_id = o.customer_id);
  IF n <> 0 THEN errors := errors || format(E'\n  orders.customer_id: %s orphans', n); END IF;

  SELECT count(*) INTO n FROM core.order_items i
   WHERE NOT EXISTS (SELECT 1 FROM core.orders o WHERE o.order_id = i.order_id);
  IF n <> 0 THEN errors := errors || format(E'\n  order_items.order_id: %s orphans', n); END IF;

  SELECT count(*) INTO n FROM core.order_items i
   WHERE NOT EXISTS (SELECT 1 FROM core.products p WHERE p.product_id = i.product_id);
  IF n <> 0 THEN errors := errors || format(E'\n  order_items.product_id: %s orphans', n); END IF;

  SELECT count(*) INTO n FROM core.order_items i
   WHERE NOT EXISTS (SELECT 1 FROM core.sellers s WHERE s.seller_id = i.seller_id);
  IF n <> 0 THEN errors := errors || format(E'\n  order_items.seller_id: %s orphans', n); END IF;

  SELECT count(*) INTO n FROM core.payments p
   WHERE NOT EXISTS (SELECT 1 FROM core.orders o WHERE o.order_id = p.order_id);
  IF n <> 0 THEN errors := errors || format(E'\n  payments.order_id: %s orphans', n); END IF;

  SELECT count(*) INTO n FROM core.order_reviews r
   WHERE NOT EXISTS (SELECT 1 FROM core.orders o WHERE o.order_id = r.order_id);
  IF n <> 0 THEN errors := errors || format(E'\n  order_reviews.order_id: %s orphans', n); END IF;

  IF errors <> '' THEN
    RAISE EXCEPTION 'Phase 2 foreign keys would fail:%', errors;
  END IF;
  RAISE NOTICE '  ok    every Phase 2 foreign key would hold';
  RAISE NOTICE 'core verified: counts, keys, cleaning rules and referential integrity';
END $$;
