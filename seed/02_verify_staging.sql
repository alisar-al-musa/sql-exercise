-- Verify the staging load against the row counts recorded when the dataset
-- was downloaded. A short count means COPY silently dropped rows; a long one
-- means a stray newline inside a field split a record in two. Either way we
-- want a loud failure here rather than a quiet wrong answer three phases later.

DO $$
DECLARE
  expected CONSTANT TEXT[][] := ARRAY[
    ['customers',                        '99441'],
    ['geolocation',                      '1000163'],
    ['orders',                           '99441'],
    ['order_items',                      '112650'],
    ['order_payments',                   '103886'],
    ['order_reviews',                    '99224'],
    ['products',                         '32951'],
    ['sellers',                          '3095'],
    ['product_category_name_translation','71']
  ];
  tbl    TEXT;
  want   BIGINT;
  got    BIGINT;
  errors TEXT := '';
BEGIN
  FOR i IN 1 .. array_length(expected, 1) LOOP
    tbl  := expected[i][1];
    want := expected[i][2]::BIGINT;
    EXECUTE format('SELECT count(*) FROM staging.%I', tbl) INTO got;

    IF got = want THEN
      RAISE NOTICE '  ok    staging.% = %', rpad(tbl, 34), got;
    ELSE
      errors := errors || format(E'\n  staging.%s: expected %s, got %s', tbl, want, got);
    END IF;
  END LOOP;

  IF errors <> '' THEN
    RAISE EXCEPTION 'staging row counts do not match the source CSVs:%', errors;
  END IF;

  RAISE NOTICE 'staging verified: all 9 tables match the source CSVs';
END $$;
