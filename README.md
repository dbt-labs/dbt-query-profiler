# dbt_query_profiler

A dbt package for querying and analyzing query history and execution plans across data warehouses.

## Supported adapters

| Feature | Snowflake | BigQuery | Databricks | Redshift | DuckDB |
|---------|:---------:|:--------:|:----------:|:--------:|:------:|
| Query History | ✅ | ✅ | ✅*** | ✅ | ✅* |
| Query SQL | ✅ | ✅ | ✅*** | ✅ | ✅* |
| Query Plan (EXPLAIN) | ✅ | ❌ | ✅ | ✅ | ✅ |
| Execution Plan | ✅ | ✅† | ✅*** | ✅ | ✅* |
| Query Stats | ✅ | ✅ | ✅*** | ✅ | ✅** |

\* DuckDB requires logging enabled with `CALL enable_logging('QueryLog', storage_path = 'path/to/logs');` for cross-session profiling

\** DuckDB query stats **re-executes the query** via `EXPLAIN ANALYZE`

\*** Databricks requires access to `system.query.history` (Query Plan works without it)

† BigQuery does not expose operator-level execution plans. `print_execution_plan` returns **Query Insights** (`performance_insights` from `INFORMATION_SCHEMA`) — performance diagnostics such as slot contention, high cardinality joins, and partition skew. See [BigQuery Query Insights](https://cloud.google.com/bigquery/docs/query-insights).

## Built for AI agents

Behind one interface, this package encodes five warehouses' native query-history mechanics: Snowflake's `get_query_operator_stats()`, BigQuery's `INFORMATION_SCHEMA.JOBS_BY_USER`, Databricks' `system.query.history`, Redshift's `stl_explain` reached through `stl_query` correlated by transaction id (`xid`), and DuckDB's `duckdb_logs`. An agent calling `print_query_stats` or `print_execution_plan` runs the same triage loop — find the query, check the plan, check the stats — on any of them without knowing any of that.

Install the companion skill so your agent knows how to use it. Run this from your **main project directory** (where `dbt_packages/` lives):

```bash
npx skills add ./dbt_packages/dbt_query_profiler/.claude/skills/using-dbt-query-profiler-package
```

This installs the `using-dbt-query-profiler-package` skill, which teaches your AI agent how to use the profiler — getting query IDs, retrieving execution plans, comparing model performance, and interpreting results.

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

## Quickstart

Profile a model by name — no query IDs, no node IDs:

```bash
dbt run-operation print_query_stats --args '{model_name: my_model}'
dbt run-operation print_execution_plan --args '{model_name: my_model, format: text}'
```

## Requirements and limitations

- **Depends on the query comment.** `model_name` (and `node_id`) resolution reads `node_id` out of dbt's default `query_comment`, which is embedded in every statement dbt sends to the warehouse. If your project overrides `query_comment`, keep `node_id` in it — this feature has no other way to find a model's statements in query history.
- **`model_name` only resolves models.** `resolve_node_id` matches against `resource_type == 'model'` in the dbt graph, so snapshots and seeds are not resolvable by `model_name`. Use `node_id=` for those instead — it's a substring match against the query comment, not a graph lookup, so it works for any resource type (e.g. `node_id: snapshot.my_project.my_snapshot`).
- **Statement selection is an approximation.** dbt's query comment carries no `invocation_id`, so the exact run boundary can't be recovered from query history. Resolution picks the slowest of the `num_candidates` (default 10) most recent statements for that node, out of the last `result_limit` (default 1000) statements in that adapter's history source (`total_elapsed_time` desc, ties broken by longest query text, then most recent start time). On DuckDB, whose `duckdb_logs` has no duration column, every candidate ties and the longest statement wins instead — normally the model's real build, not the short `drop`/`alter` housekeeping statements around it. Whichever statement is chosen is always logged with how many candidates were considered and a short preview of its SQL (the query comment is stripped first, so the preview is the SQL itself, not dbt's boilerplate), e.g. `chose query_id ... (slowest of 3 recent statements for this model) - create table "my_model__dbt_tmp" as ( select ...`, so a wrong pick is visible immediately. If the model actually ran further back than `result_limit` other statements ago, resolution reports "No queries found" — raise `result_limit`.
- **Query history has per-adapter latency and retention.** In testing, Databricks' `system.query.history` lagged roughly three minutes behind the query actually running, and Redshift's `stl_query`/`stl_explain` tables are pruned aggressively. A model profiled seconds after it runs may not be visible yet — wait and retry before assuming a bug.
- **Custom `get_query_history` overrides need a `node_id` parameter.** The core `get_query_history` macro now always passes `node_id` (and resolves `model_name` to it) to `adapter.dispatch(...)`, unconditionally. If your project defines its own out-of-tree `<adapter>__get_query_history` override, add a `node_id=none` parameter to its signature or the dispatch call will fail with an unexpected-keyword-argument error.

## Configuration

By default, macros use **user-scoped** views that require no special permissions and only show queries from the current user. To access queries from all users (requires elevated permissions), set:

```yaml
# dbt_project.yml
vars:
  use_account_level_history: true  # default: false
```

| Setting | User-Scoped (default) | Account-Level |
|---------|----------------------|---------------|
| **Snowflake** | `information_schema.query_history_by_user()` (falls back to `query_history()` if no user is resolved) | `snowflake.account_usage.query_history` |
| **BigQuery** | `INFORMATION_SCHEMA.JOBS_BY_USER` | `INFORMATION_SCHEMA.JOBS_BY_PROJECT` |
| **Databricks** | `system.query.history` filtered by `current_user()` | `system.query.history` (all users) |
| **Redshift** | `sys_query_history` filtered by user | `sys_query_history` (all users) — see note |

**Redshift note:** Redshift has no separate account-level source. `sys_query_history` is a single
view whose visibility depends on the connected user's privileges: superusers see all rows, and
regular users see only their own unless granted `SYSLOG ACCESS UNRESTRICTED`
([docs](https://docs.aws.amazon.com/redshift/latest/dg/SYS_QUERY_HISTORY.html)). Setting
`use_account_level_history: true` stops the package filtering by username, but it cannot grant
access — without the privilege you will still only see your own queries.

### Custom query history source

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

### Query history

Get recent queries:
```bash
# Get last 5 SELECT queries
dbt run-operation print_query_history --args '{limit: 5, query_type: SELECT}'

# Get queries touching a specific table
dbt run-operation print_query_history --args '{table_name: customers, limit: 10}'

# Get queries from all users (Snowflake)
dbt run-operation print_query_history --args '{user_name: "", limit: 5}'

# Get all recent statements for a specific model, instead of just the one picked for profiling
dbt run-operation print_query_history --args '{model_name: my_model, limit: 10}'
```

### Query SQL

Get the SQL text for a specific query:
```bash
dbt run-operation print_query_sql --args '{query_id: "01c20db1-060a-bcad-0004-7d832cd6b002"}'
```

### Query plan (estimated)

Get the estimated execution plan for any SQL query using EXPLAIN:
```bash
# From raw SQL
dbt run-operation print_query_plan --args '{sql: "SELECT * FROM my_table WHERE id = 1"}'

# With format option
dbt run-operation print_query_plan --args '{sql: "SELECT 1", format: text}'
```

**Note:** This runs EXPLAIN on the SQL without executing it. No query history access required.

### Execution plan (actual)

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

### Query stats

Get execution statistics for a query:
```bash
# JSON format (default)
dbt run-operation print_query_stats --args '{query_id: "01c20db1-..."}'

# Text format (terminal-friendly)
dbt run-operation print_query_stats --args '{query_id: "01c20db1-...", format: text}'
```

<details>
<summary>Sample text output, one per adapter</summary>

Snowflake:
```
Query ID:     01c20db1-060a-bcad-0004-7d832cd6b002
Status:       SUCCESS
Duration:     1234 ms
Bytes Read:   1,048,576
Rows:         10,000
Bytes Out:    524,288
```

BigQuery:
```
Query ID:     bquxjob_abc123_0123456789
Status:       DONE
Duration:     2500 ms
Bytes Read:   5,242,880
Bytes Billed: 10,485,760
Cache Hit:    False
Slot MS:      15000
```

Databricks:
```
Query ID:     01234567-89ab-cdef-0123-456789abcdef
Status:       FINISHED
Duration:     1500 ms
Bytes Read:   2,097,152
Rows:         5,000
Bytes Out:    1,048,576
Cache Hit:    False
```

Redshift:
```
Query ID:     12345678
Status:       success
Duration:     850 ms
Bytes Out:    1,048,576
Rows:         5,000
Cache Hit:    True
```

</details>

## Profile the slowest models from a run

`target/run_results.json` already has each model's execution time after a `dbt build` or `dbt run`. This script ranks the slowest ones and profiles each by `node_id` directly — no manual query-ID lookups.

<details>
<summary>rank_and_profile.py</summary>

```python
#!/usr/bin/env python3
"""Rank models by execution time from run_results.json, then profile the slowest."""
import json
import subprocess
import sys

TOP_N = 3

def slowest_models(run_results_path, top_n=TOP_N):
    """Return (node_id, seconds) for the slowest successful models, slowest first."""
    with open(run_results_path) as fh:
        results = json.load(fh)["results"]
    models = [
        (r["unique_id"], r["execution_time"])
        for r in results
        if r["unique_id"].startswith("model.") and r["status"] == "success"
    ]
    return sorted(models, key=lambda pair: pair[1], reverse=True)[:top_n]

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "target/run_results.json"
    target = sys.argv[2] if len(sys.argv) > 2 else None

    for node_id, seconds in slowest_models(path):
        print(f"\n=== {node_id} — {seconds:.1f}s per dbt ===")
        cmd = [
            "dbt", "run-operation", "print_query_stats",
            "--args", f"{{node_id: {node_id}}}",
        ]
        if target:
            cmd += ["--target", target]
        subprocess.run(cmd, check=False)

if __name__ == "__main__":
    main()
```

</details>

The commands below are this package's own `integration_tests` project — in your project, just run `dbt build` (or `dbt run`) then point the script at your `target/run_results.json`. The script shells out to plain `dbt`, so run it where `dbt` resolves on your `PATH`:

```bash
cd integration_tests
export DBT_PROFILES_DIR=$PWD/profiles DUCKDB_PATH=target/t.duckdb
dbt build --target duckdb --select tag:setup --full-refresh
uv run --python 3.11 python rank_and_profile.py target/run_results.json duckdb
```

Real output against this package's own integration test project (dbt's per-call startup banner omitted for brevity; each `{ ... }` is a full JSON payload because DuckDB's query stats re-executes the query via `EXPLAIN ANALYZE`):

```
=== model.dbt_query_profiler_integration_tests.setup_second_model — 0.1s per dbt ===
dbt_query_profiler: profiling model.dbt_query_profiler_integration_tests.setup_second_model
  chose query_id 70:1785321074942803 - unknown type, duration unavailable on this adapter, 2026-07-29 12:31:14.942803+02:00
{ ... }

=== model.dbt_query_profiler_integration_tests.setup_enable_logging — 0.1s per dbt ===
dbt_query_profiler: profiling model.dbt_query_profiler_integration_tests.setup_enable_logging
  chose query_id 66:1785321074942537 - unknown type, duration unavailable on this adapter, 2026-07-29 12:31:14.942537+02:00
{ ... }

=== model.dbt_query_profiler_integration_tests.setup_test_queries — 0.0s per dbt ===
dbt_query_profiler: profiling model.dbt_query_profiler_integration_tests.setup_test_queries
  chose query_id 127:1785321074985640 - unknown type, duration unavailable on this adapter, 2026-07-29 12:31:14.985640+02:00
{ ... }
```

Every model on DuckDB shows "duration unavailable on this adapter" — that's the no-duration tiebreak from [Requirements and limitations](#requirements-and-limitations), and it still picked the right statement each time.

## Macros reference

<details>
<summary>Full argument reference for every macro</summary>

### Query history

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
- `node_id` (string): Filter by dbt node id (e.g. `model.my_project.my_model`), matched against the node id embedded in dbt's default query comment
- `model_name` (string): Filter by dbt model name, resolved to a node id via the dbt graph. Mutually exclusive with `node_id`

### Query SQL

| Macro | Description |
|-------|-------------|
| `get_query_sql()` | Returns SQL to get query text for a query ID |
| `print_query_sql()` | Executes and prints the query text |

**Arguments:**
- `query_id` (string): The query ID
- `model_name` (string): Profile a dbt model by name instead of a query ID. Resolved to a node id via the dbt graph, then matched against dbt's query comment. Mutually exclusive with `query_id` and `node_id`.
- `node_id` (string): Profile by dbt node id (e.g. `model.my_project.my_model`), skipping graph lookup. Useful when you already have one, e.g. from `run_results.json`. Mutually exclusive with `query_id` and `model_name`.
- `num_candidates` (int): Number of recent statements for the resolved node to consider when picking which one to profile (default: 10)

### Query plan (estimated)

| Macro | Description |
|-------|-------------|
| `get_query_plan(sql)` | Returns EXPLAIN output for the given SQL |
| `print_query_plan(sql)` | Prints EXPLAIN output |

**Arguments:**
- `sql` (string): The SQL query to explain
- `format` (string): Output format - 'text' (default), 'json'

### Execution plan (actual)

| Macro | Description |
|-------|-------------|
| `get_execution_plan(query_id)` | Returns actual execution statistics for a query |
| `print_execution_plan(query_id)` | Prints execution plan in json/text/markdown format |
| `get_execution_plan_summary(query_id)` | Returns summarized execution metrics |

**Arguments:**
- `query_id` (string): The query ID from query history
- `format` (string): Output format - 'json', 'text', or 'markdown' (Snowflake)
- `model_name` (string): Profile a dbt model by name instead of a query ID. Resolved to a node id via the dbt graph, then matched against dbt's query comment. Mutually exclusive with `query_id` and `node_id`.
- `node_id` (string): Profile by dbt node id (e.g. `model.my_project.my_model`), skipping graph lookup. Useful when you already have one, e.g. from `run_results.json`. Mutually exclusive with `query_id` and `model_name`.
- `num_candidates` (int): Number of recent statements for the resolved node to consider when picking which one to profile (default: 10)

### Query stats

| Macro | Description |
|-------|-------------|
| `get_query_stats()` | Returns SQL for execution statistics |
| `print_query_stats()` | Prints execution stats in json/text format |

**Arguments:**
- `query_id` (string): The query ID
- `format` (string): Output format - 'json' (default) or 'text'
- `result_limit` (int): Lookback depth (default: 10000, max: 10000 for Snowflake)
- `model_name` (string): Profile a dbt model by name instead of a query ID. Resolved to a node id via the dbt graph, then matched against dbt's query comment. Mutually exclusive with `query_id` and `node_id`.
- `node_id` (string): Profile by dbt node id (e.g. `model.my_project.my_model`), skipping graph lookup. Useful when you already have one, e.g. from `run_results.json`. Mutually exclusive with `query_id` and `model_name`.
- `num_candidates` (int): Number of recent statements for the resolved node to consider when picking which one to profile (default: 10)

**Snowflake metrics:** bytes_scanned, bytes_written_to_result, rows_produced, compilation_time, queue_time, credits

**BigQuery metrics:** bytes_processed, bytes_billed, cache_hit, slot_ms, bi_engine_mode, dml_statistics (rows inserted/updated/deleted), resource_warning

**Databricks metrics:** bytes_scanned, bytes_written, rows_produced, read_rows, compilation_duration, execution_duration, queue_time, cache_hit, spilled_local_bytes, shuffle_read_bytes

**Redshift metrics:** returned_bytes, returned_rows, compile_time, execution_time, queue_time, planning_time, result_cache_hit

</details>

## Adapter notes

Permissions and quirks together, one collapsed section per adapter.

<details>
<summary>Snowflake</summary>

| Mode | Source | Permissions Required | Retention | Latency |
|------|--------|---------------------|-----------|---------|
| User-scoped (default) | `information_schema.query_history()` | None (own queries only) | 7 days | None |
| Account-level | `snowflake.account_usage.query_history` | `IMPORTED PRIVILEGES` on `SNOWFLAKE` database | 365 days | Up to 45 min |

- **Query Plan:** Requires no additional permissions (uses `get_query_operator_stats()`)
- Query history uses `query_history_by_user()` when filtering by user, for better performance
- A query tag (`dbt_query_profiler`) is set to exclude the macro's own queries from results
- `result_limit` max is 10,000

</details>

<details>
<summary>BigQuery</summary>

| Mode | Source | Permissions Required | Retention |
|------|--------|---------------------|-----------|
| User-scoped (default) | `INFORMATION_SCHEMA.JOBS_BY_USER` | None (own jobs only) | 180 days |
| Project-level | `INFORMATION_SCHEMA.JOBS_BY_PROJECT` | `bigquery.jobs.list` or `BigQuery Resource Viewer` role | 180 days |

- Query plan (EXPLAIN) is not available via SQL (use the BigQuery console or API)
- **Execution Plan:** Returns [Query Insights](https://cloud.google.com/bigquery/docs/query-insights) instead of an operator-level plan — diagnostics include slot contention, high cardinality joins, partition skew, and shuffle quota issues. Returns `null` insights if no performance issues were detected.
- Region is read from `target.location` in your profile (defaults to 'us' if not set)

</details>

<details>
<summary>Databricks</summary>

| Mode | Source | Permissions Required | Retention |
|------|--------|---------------------|-----------|
| User-scoped (default) | `system.query.history` (filtered) | `USE CATALOG` on `system`, `USE SCHEMA` on `system.query`, `SELECT` on `system.query.history` | 90 days |
| Account-level | `system.query.history` (all users) | Same as above | 90 days |

By default, only metastore admins have access to `system.query.history`. Admins can grant access:
```sql
GRANT USE CATALOG ON CATALOG system TO `user@example.com`;
GRANT USE SCHEMA ON SCHEMA system.query TO `user@example.com`;
GRANT SELECT ON TABLE system.query.history TO `user@example.com`;
```

- **Query Plan:** Uses `EXPLAIN` directly on SQL you provide — does NOT require `system.query.history` access
- **Execution Plan:** Retrieves SQL from query history, then runs EXPLAIN — requires `system.query.history` access
- The `statement_id` can be found in the Query History UI or SQL warehouse logs
- `system.query.history` can lag the query actually running by a few minutes — see [Requirements and limitations](#requirements-and-limitations)

</details>

<details>
<summary>Redshift</summary>

| Mode | Source | Permissions Required | Retention |
|------|--------|---------------------|-----------|
| User-scoped (default) | `sys_query_history` | None (own queries only) | 2-5 days |
| Account-level | `sys_query_history` | Superuser access | 2-5 days |

- **Query Plan:** Uses `stl_explain` system table (available to all users for their own queries), reached through `stl_query` correlated by transaction id (`xid`) — see [AWS's note on correlating these tables](https://repost.aws/knowledge-center/redshift-query-id-match-tables)
- `sys_query_history` is preferred over the older `stl_query` for Query History, Query SQL, Execution Plan, and Query Stats
- System tables retain 2-5 days of history depending on usage, and are pruned aggressively — see [Requirements and limitations](#requirements-and-limitations)
- Query ID is a bigint (not a UUID like other platforms)

</details>

<details>
<summary>DuckDB</summary>

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

- Query plan uses `EXPLAIN` (does not re-execute) and supports `text`, `json`, `graphviz`, and `html` formats
- **Query stats will re-execute the query** using `EXPLAIN ANALYZE` to capture actual execution metrics
- Query ID is the `rowid` from the logs table
- `total_elapsed_time` is always NULL (`duckdb_logs` has no duration column) — see the DuckDB tiebreak in [Requirements and limitations](#requirements-and-limitations)

</details>

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new adapters
4. Submit a pull request

## License

Apache 2.0
