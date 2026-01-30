# dbt_query_profiler

A dbt package for querying and analyzing query history and execution plans across data warehouses.

## Supported Adapters

| Feature | Snowflake | BigQuery | Databricks | Redshift | DuckDB |
|---------|:---------:|:--------:|:----------:|:--------:|:------:|
| Query History | ✅ | ✅ | ✅*** | ✅ | ✅* |
| Query SQL | ✅ | ✅ | ✅*** | ✅ | ✅* |
| Query Plan (EXPLAIN) | ✅ | ❌ | ✅ | ✅ | ✅ |
| Execution Plan | ✅ | ❌ | ✅*** | ✅ | ✅* |
| Query Stats | ✅ | ✅ | ✅*** | ✅ | ✅** |

\* DuckDB requires logging enabled with `CALL enable_logging('QueryLog', storage_path = 'path/to/logs');` for cross-session profiling

\** DuckDB query stats **re-executes the query** via `EXPLAIN ANALYZE`

\*** Databricks requires access to `system.query.history` (Query Plan works without it)

## Installation

Add to your `packages.yml`:

```yaml
packages:
  - git: "https://github.com/dbt-labs/dbt-query-profiler.git"
    revision: main
```

Then run:
```bash
dbt deps
```

## Configuration

By default, macros use **user-scoped** views that require no special permissions and only show queries from the current user. To access queries from all users (requires elevated permissions), set:

```yaml
# dbt_project.yml
vars:
  use_account_level_history: true  # default: false
```

| Setting | User-Scoped (default) | Account-Level |
|---------|----------------------|---------------|
| **Snowflake** | `information_schema.query_history()` | `snowflake.account_usage.query_history` |
| **BigQuery** | `INFORMATION_SCHEMA.JOBS_BY_USER` | `INFORMATION_SCHEMA.JOBS_BY_PROJECT` |
| **Databricks** | `system.query.history` filtered by `current_user()` | `system.query.history` (all users) |
| **Redshift** | `sys_query_history` filtered by user | `sys_query_history` (all users) |

### Custom Query History Source

If your admin provides access to query history via a custom view (instead of the default system tables), you can override the source:

```yaml
# dbt_project.yml
vars:
  # Use a custom view instead of the default system table
  snowflake_query_history_source: "my_db.audit.query_history_view"
  databricks_query_history_source: "main.audit.query_history_view"
  bigquery_query_history_source: "my_project.audit.jobs_view"
  redshift_query_history_source: "admin.query_history_view"
```

**Note:** When a custom source is set, `use_account_level_history` is ignored for that adapter. The custom view controls what data is accessible.

Your custom view must have columns compatible with the expected schema (e.g., `query_id`, `query_text`, `user_name`, `start_time`, etc.).

## Usage

### Query History

Get recent queries:
```bash
# Get last 5 SELECT queries
dbt run-operation print_query_history --args '{limit: 5, query_type: SELECT}'

# Get queries touching a specific table
dbt run-operation print_query_history --args '{table_name: customers, limit: 10}'

# Get queries from all users (Snowflake)
dbt run-operation print_query_history --args '{user_name: "", limit: 5}'
```

### Query SQL

Get the SQL text for a specific query:
```bash
dbt run-operation print_query_sql --args '{query_id: "01c20db1-060a-bcad-0004-7d832cd6b002"}'
```

### Query Plan (Estimated)

Get the estimated execution plan for any SQL query using EXPLAIN:
```bash
# From raw SQL
dbt run-operation print_query_plan --args '{sql: "SELECT * FROM my_table WHERE id = 1"}'

# With format option
dbt run-operation print_query_plan --args '{sql: "SELECT 1", format: text}'
```

**Note:** This runs EXPLAIN on the SQL without executing it. No query history access required.

### Execution Plan (Actual)

Get the actual execution plan from a previously run query:
```bash
# JSON format (default)
dbt run-operation print_execution_plan --args '{query_id: "01c20db1-..."}'

# Text format (terminal-friendly)
dbt run-operation print_execution_plan --args '{query_id: "01c20db1-...", format: text}'

# Markdown table (Snowflake only)
dbt run-operation print_execution_plan --args '{query_id: "01c20db1-...", format: markdown}'
```

Example text output (Snowflake):
```
[0] CREATE TABLE  (in: -, out: -, time: 100%)
[1] CreateTableAsSelect  (in: 128, out: 0, time: 33.3%)
[2] Join  (in: 256, out: 128, time: 0%)
[3] TableScan  (in: -, out: 128, time: 0%)
```

**Note:** This retrieves actual execution statistics from the query history. Requires query history access.

### Query Stats

Get execution statistics for a query:
```bash
# JSON format (default)
dbt run-operation print_query_stats --args '{query_id: "01c20db1-..."}'

# Text format (terminal-friendly)
dbt run-operation print_query_stats --args '{query_id: "01c20db1-...", format: text}'
```

Example text output (Snowflake):
```
Query ID:     01c20db1-060a-bcad-0004-7d832cd6b002
Status:       SUCCESS
Duration:     1234 ms
Bytes Read:   1,048,576
Rows:         10,000
Bytes Out:    524,288
```

Example text output (BigQuery):
```
Query ID:     bquxjob_abc123_0123456789
Status:       DONE
Duration:     2500 ms
Bytes Read:   5,242,880
Bytes Billed: 10,485,760
Cache Hit:    False
Slot MS:      15000
```

Example text output (Databricks):
```
Query ID:     01234567-89ab-cdef-0123-456789abcdef
Status:       FINISHED
Duration:     1500 ms
Bytes Read:   2,097,152
Rows:         5,000
Bytes Out:    1,048,576
Cache Hit:    False
```

Example text output (Redshift):
```
Query ID:     12345678
Status:       success
Duration:     850 ms
Bytes Out:    1,048,576
Rows:         5,000
Cache Hit:    True
```

## Macros Reference

### Query History

| Macro | Description |
|-------|-------------|
| `get_query_history()` | Returns SQL to query history (for use in models) |
| `print_query_history()` | Executes and prints query history as JSON |

**Arguments:**
- `table_name` (string): Filter by table name in query text
- `user_name` (string): Filter by user (defaults to target.user, empty string disables)
- `query_type` (string): Filter by type (SELECT, INSERT, CREATE_TABLE_AS_SELECT, etc.)
- `limit` (int): Number of queries to return (default: 1)
- `result_limit` (int): Lookback depth (default: 100, max: 10000)

### Query SQL

| Macro | Description |
|-------|-------------|
| `get_query_sql()` | Returns SQL to get query text for a query ID |
| `print_query_sql()` | Executes and prints the query text |

**Arguments:**
- `query_id` (string): The query ID

### Query Plan (Estimated)

| Macro | Description |
|-------|-------------|
| `get_query_plan(sql)` | Returns EXPLAIN output for the given SQL |
| `print_query_plan(sql)` | Prints EXPLAIN output |

**Arguments:**
- `sql` (string): The SQL query to explain
- `format` (string): Output format - 'text' (default), 'json'

### Execution Plan (Actual)

| Macro | Description |
|-------|-------------|
| `get_execution_plan(query_id)` | Returns actual execution statistics for a query |
| `print_execution_plan(query_id)` | Prints execution plan in json/text/markdown format |
| `get_execution_plan_summary(query_id)` | Returns summarized execution metrics |

**Arguments:**
- `query_id` (string): The query ID from query history
- `format` (string): Output format - 'json', 'text', or 'markdown' (Snowflake)

### Query Stats

| Macro | Description |
|-------|-------------|
| `get_query_stats()` | Returns SQL for execution statistics |
| `print_query_stats()` | Prints execution stats in json/text format |

**Arguments:**
- `query_id` (string): The query ID
- `format` (string): Output format - 'json' (default) or 'text'
- `result_limit` (int): Lookback depth (default: 10000, max: 10000 for Snowflake)

**Snowflake metrics:** bytes_scanned, bytes_written_to_result, rows_produced, compilation_time, queue_time, credits

**BigQuery metrics:** bytes_processed, bytes_billed, cache_hit, slot_ms, bi_engine_mode, dml_statistics (rows inserted/updated/deleted), resource_warning

**Databricks metrics:** bytes_scanned, bytes_written, rows_produced, read_rows, compilation_duration, execution_duration, queue_time, cache_hit, spilled_local_bytes, shuffle_read_bytes

**Redshift metrics:** returned_bytes, returned_rows, compile_time, execution_time, queue_time, planning_time, result_cache_hit

## Permissions

### Snowflake

| Mode | Source | Permissions Required | Retention | Latency |
|------|--------|---------------------|-----------|---------|
| User-scoped (default) | `information_schema.query_history()` | None (own queries only) | 7 days | None |
| Account-level | `snowflake.account_usage.query_history` | `IMPORTED PRIVILEGES` on `SNOWFLAKE` database | 365 days | Up to 45 min |

**Query Plan:** Requires no additional permissions (uses `get_query_operator_stats()`)

### BigQuery

| Mode | Source | Permissions Required | Retention |
|------|--------|---------------------|-----------|
| User-scoped (default) | `INFORMATION_SCHEMA.JOBS_BY_USER` | None (own jobs only) | 180 days |
| Project-level | `INFORMATION_SCHEMA.JOBS_BY_PROJECT` | `bigquery.jobs.list` or `BigQuery Resource Viewer` role | 180 days |

### Databricks

| Mode | Source | Permissions Required | Retention |
|------|--------|---------------------|-----------|
| User-scoped (default) | `system.query.history` (filtered) | `USE CATALOG` on `system`, `USE SCHEMA` on `system.query`, `SELECT` on `system.query.history` | 90 days |
| Account-level | `system.query.history` (all users) | Same as above | 90 days |

**Note:** By default, only metastore admins have access to `system.query.history`. Admins can grant access:
```sql
GRANT USE CATALOG ON CATALOG system TO `user@example.com`;
GRANT USE SCHEMA ON SCHEMA system.query TO `user@example.com`;
GRANT SELECT ON TABLE system.query.history TO `user@example.com`;
```

**Query Plan:** Uses `EXPLAIN` directly on SQL you provide - no `system.query.history` access required

### Redshift

| Mode | Source | Permissions Required | Retention |
|------|--------|---------------------|-----------|
| User-scoped (default) | `sys_query_history` | None (own queries only) | 2-5 days |
| Account-level | `sys_query_history` | Superuser access | 2-5 days |

**Query Plan:** Uses `stl_explain` system table (available to all users for their own queries)

### DuckDB

DuckDB requires query logging to be explicitly enabled:
```sql
CALL enable_logging('QueryLog');
```

Once enabled, queries are logged to the `duckdb_logs` view.

**Cross-session profiling:** By default, DuckDB logs are stored in memory and lost when the session ends. To profile queries across sessions (e.g., via separate `dbt run-operation` commands), use file-based logging:
```sql
CALL enable_logging('QueryLog', storage_path = 'path/to/logs');
```
When you enable logging with the same `storage_path` in a new session, logs from previous sessions become available.

**Note:** `get_query_stats()` for DuckDB will **re-execute the query** using `EXPLAIN ANALYZE` to capture actual execution metrics.

## Platform-Specific Notes

### Snowflake

- **User-scoped (default):** Uses `information_schema.query_history()` - 7 days retention, no latency
- **Account-level:** Uses `snowflake.account_usage.query_history` - 365 days retention, up to 45 min latency
- Query history uses `query_history_by_user()` when filtering by user for better performance
- Query plan uses `get_query_operator_stats()` for detailed execution metrics
- A query tag (`dbt_query_profiler`) is set to exclude the macro's own queries from results
- `result_limit` max is 10,000

### BigQuery

- **User-scoped (default):** Uses `INFORMATION_SCHEMA.JOBS_BY_USER` - only current user's jobs
- **Project-level:** Uses `INFORMATION_SCHEMA.JOBS_BY_PROJECT` - all jobs in project
- Query plan is not available via SQL (use BigQuery console or API)
- Use `get_query_stats()` for high-level execution metrics as an alternative to query plans
- Region is read from `target.location` in your profile (defaults to 'us' if not set)

### Databricks

- Uses `system.query.history` system table for Query History, Query SQL, Execution Plan, and Query Stats
- **User-scoped (default):** Filters by `current_user()` - only your own queries
- **Account-level:** Shows all users' queries (requires same permissions)
- **Query Plan:** Uses `EXPLAIN` directly on SQL you provide - does NOT require `system.query.history` access
- **Execution Plan:** Retrieves SQL from query history, then runs EXPLAIN - requires `system.query.history` access
- The `statement_id` can be found in the Query History UI or SQL warehouse logs

### Redshift

- Uses `sys_query_history` system view (recommended over older `stl_query`)
- Query plan uses `stl_explain` for execution plan details
- System tables retain 2-5 days of history depending on usage
- Query ID is a bigint (not a UUID like other platforms)

### DuckDB

- Requires logging to be enabled with `CALL enable_logging('QueryLog');`
- Query history is read from `duckdb_logs` view
- **In-memory logging (default):** Logs are lost when session ends
- **File-based logging:** Use `CALL enable_logging('QueryLog', storage_path = 'path/to/logs');` to persist logs across sessions
- Query plan uses `EXPLAIN` (does not re-execute)
- Supports formats: `text`, `json`, `graphviz`, `html`
- **Query stats will re-execute the query** via `EXPLAIN ANALYZE` to get actual metrics
- Query ID is the `rowid` from the logs table

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new adapters
4. Submit a pull request

## License

Apache 2.0
