# Integration Tests TODO

## DuckDB Testing Limitations

DuckDB query logging is **session-scoped**, which creates challenges for integration testing:

### Issue 1: Logs don't persist across dbt commands

Each `dbt` invocation creates a new DuckDB connection/session. When you run:
```bash
dbt build --select tag:setup   # Session 1: creates queries, logs them
dbt test                        # Session 2: no logs from Session 1
```

The logs from Session 1 are not available in Session 2, even with a persistent `.duckdb` file.

### Issue 2: `test_get_query_history_filters_by_table` fails

This test searches for queries containing `test_query_profiler_marker`. Even when running `dbt build` (same session), the test fails because:
- The setup model runs and creates a query with the marker
- The test runs after and queries `duckdb_logs`
- But the marker query isn't found in the logs

**Possible causes to investigate:**
1. DuckDB might not log all queries (e.g., CREATE TABLE AS SELECT)
2. There may be a timing issue with when logs become queryable
3. The `_self_identifier` filter (`message not like '%dbt_query_profiler%'`) might be too aggressive
4. dbt-duckdb adapter might use connection pooling that affects logging scope

### Issue 3: `run-operation` tests can't work for DuckDB

Since each `dbt run-operation` is a new session, the `print_*` macros can't access query history from previous commands. These tests are skipped for DuckDB.

### Current Workarounds

1. `test_get_query_history_filters_by_table` is disabled for DuckDB via `config(enabled=(target.type != 'duckdb'))`
2. `test_run_operations.sh` skips all tests for DuckDB target
3. Other tests work by checking that the logging infrastructure exists (not specific queries)

### Investigation Steps

To debug, try:
```sql
-- In a DuckDB session
CALL enable_logging('QueryLog');

-- Run some queries
SELECT 1;
CREATE TABLE test AS SELECT 2;

-- Check what was logged
SELECT * FROM duckdb_logs WHERE type = 'QueryLog';
```

Check if CREATE TABLE statements are logged differently than SELECT statements.

### Potential Solutions

1. **Accept the limitation**: DuckDB logging is for local debugging, not CI testing
2. **Use a pre-populated test database**: Create a `.duckdb` file with known query history
3. **Test compilation only**: For DuckDB, just verify macros compile (`dbt parse`)
4. **Investigate dbt-duckdb internals**: Check if there's a way to persist logs or use a single connection
