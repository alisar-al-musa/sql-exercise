-- Column-level profile of every staging table.
--
-- For each column: how many rows, how many distinct values, how many nulls,
-- and what type the values actually are (tested, not assumed). This is what
-- identifies primary key candidates -- distinct = rows means unique -- and
-- separates categorical columns from continuous measures and free text.

CREATE TEMP TABLE col_profile (
  tbl        TEXT,
  col        TEXT,
  ord        INT,
  n_rows     BIGINT,
  n_distinct BIGINT,
  n_null     BIGINT,
  data_type  TEXT,
  role       TEXT
);

DO $$
DECLARE
  r          RECORD;
  n_rows     BIGINT;
  n_distinct BIGINT;
  n_null     BIGINT;
  bad_num    BIGINT;
  bad_ts     BIGINT;
  n_nonnull  BIGINT;
  dtype      TEXT;
  crole      TEXT;
BEGIN
  FOR r IN
    SELECT table_name, column_name, ordinal_position
    FROM information_schema.columns
    WHERE table_schema = 'staging'
    ORDER BY table_name, ordinal_position
  LOOP
    EXECUTE format(
      'SELECT count(*), count(DISTINCT %I), count(*) FILTER (WHERE %I IS NULL),
              count(*) FILTER (WHERE %I IS NOT NULL AND NOT pg_input_is_valid(%I, ''numeric'')),
              count(*) FILTER (WHERE %I IS NOT NULL AND NOT pg_input_is_valid(%I, ''timestamp''))
       FROM staging.%I',
      r.column_name, r.column_name, r.column_name, r.column_name,
      r.column_name, r.column_name, r.table_name)
    INTO n_rows, n_distinct, n_null, bad_num, bad_ts;

    n_nonnull := n_rows - n_null;

    -- Type is decided by what the values actually parse as, not by the name.
    dtype := CASE
      WHEN n_nonnull = 0     THEN 'all null'
      WHEN bad_num = 0       THEN 'numeric'
      WHEN bad_ts  = 0       THEN 'timestamp'
      ELSE                        'text'
    END;

    -- Role drives the schema: unique -> key candidate, low cardinality ->
    -- categorical (worth an index / CHECK), high cardinality text -> free text.
    crole := CASE
      WHEN n_nonnull = 0                      THEN '-'
      WHEN n_distinct = n_rows AND n_null = 0 THEN 'KEY CANDIDATE (unique)'
      WHEN n_distinct <= 30                   THEN 'categorical'
      WHEN dtype = 'numeric'                  THEN 'measure'
      WHEN dtype = 'timestamp'                THEN 'date'
      WHEN n_distinct::numeric / NULLIF(n_nonnull,0) > 0.9 THEN 'identifier / free text'
      ELSE                                         'high-cardinality text'
    END;

    INSERT INTO col_profile
    VALUES (r.table_name, r.column_name, r.ordinal_position,
            n_rows, n_distinct, n_null, dtype, crole);
  END LOOP;
END $$;

\echo '===== COLUMN PROFILE'
SELECT tbl AS "table", col AS "column", n_rows AS rows, n_distinct AS distinct_vals,
       n_null AS nulls, data_type AS type, role
FROM col_profile ORDER BY tbl, ord;

\echo ''
\echo '===== SUMMARY: how many columns of each type / role'
SELECT data_type AS type, role, count(*) AS columns
FROM col_profile GROUP BY 1,2 ORDER BY 3 DESC;

\echo ''
\echo '===== SINGLE-COLUMN PRIMARY KEY CANDIDATES'
SELECT tbl AS "table", col AS "column", n_rows AS rows
FROM col_profile WHERE role = 'KEY CANDIDATE (unique)' ORDER BY 1;

\echo ''
\echo '===== CATEGORICAL COLUMNS AND THEIR VALUES'
SELECT tbl AS "table", col AS "column", n_distinct AS distinct_vals
FROM col_profile WHERE role = 'categorical' ORDER BY 3, 1;
