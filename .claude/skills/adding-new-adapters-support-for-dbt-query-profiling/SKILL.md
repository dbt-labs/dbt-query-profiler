---
name: adding-new-adapters-support-for-dbt-query-profiling
description: Use when adding support for a new data warehouse adapter (e.g., Trino, Postgres, Spark) to dbt-query-profiler. Triggers include creating adapter macros, implementing query history/plan/stats, or extending platform support.
---

# Adding New Adapters to dbt-query-profiler

## Overview

This package uses `adapter.dispatch()` to route calls to adapter-specific implementations. Adding a new adapter requires creating 5 macro files, implementing self-exclusion via `_self_identifier()`, updating documentation, and adding integration tests.

## File Structure

Create these files for adapter `{adapter}`:

```
macros/{adapter}/
├── query_history.sql   # Required: query history access
├── query_sql.sql       # Required: retrieve query text
├── query_plan.sql      # Required: EXPLAIN-based plans (or raise error)
├── execution_plan.sql  # Required: actual execution stats (or raise error)
└── query_stats.sql     # Required: execution statistics
```

## Macro Naming Convention

Each macro must follow the pattern `{adapter}__{macro_name}`:

```jinja2
{% macro trino__get_query_history(table_name, user_name, query_type, limit, result_limit) %}
    -- Adapter-specific implementation
{% endmacro %}
```

## Required Macros Per File

### query_history.sql
- `{adapter}__get_query_history(table_name, user_name, query_type, limit, result_limit)`
- `{adapter}__print_query_history(table_name, user_name, query_type, limit, result_limit)`

### query_sql.sql
- `{adapter}__get_query_sql(query_id)`
- `{adapter}__print_query_sql(query_id)`

### query_plan.sql
- `{adapter}__get_query_plan(sql)`
- `{adapter}__print_query_plan(sql, format)`

### execution_plan.sql
- `{adapter}__get_execution_plan(query_id)`
- `{adapter}__print_execution_plan(query_id, format)`
- `{adapter}__get_execution_plan_summary(query_id)` (optional)

### query_stats.sql
- `{adapter}__get_query_stats(query_id, format, result_limit)`
- `{adapter}__print_query_stats(query_id, format, result_limit)`

## Self-Identifier Pattern (Critical)

The `_self_identifier()` macro returns `'__dbt_query_profiler_self__'` and **must be used to exclude the profiler's own queries** from results. The identifier uses double underscores to avoid accidentally matching project names like `dbt_query_profiler_integration_tests`.

### Implementation Approaches

**Option A: Query tags (preferred if supported)**
```jinja2
-- In get_query_history: exclude by tag
where query_tag != '{{ dbt_query_profiler._self_identifier() }}'

-- In print_query_history: set tag before executing
{% do run_query("SET QUERY_TAG = '" ~ dbt_query_profiler._self_identifier() ~ "'") %}
```

**Option B: Query text filtering (fallback)**
```jinja2
-- In get_query_history: exclude by text pattern
where query_text not like '%{{ dbt_query_profiler._self_identifier() }}%'

-- In print_query_history: add comment to query
{% set query %}
/* {{ dbt_query_profiler._self_identifier() }} */
select ...
{% endset %}
```

### Existing Adapter Approaches
| Adapter | Method |
|---------|--------|
| Snowflake | Query tags via `ALTER SESSION SET QUERY_TAG` |
| BigQuery | Comment prefix in query text |
| Databricks | Comment prefix in query text |
| Redshift | Comment prefix in query text |
| DuckDB | Comment prefix in query text |

## Return Value Standards

### get_* macros
Return a SQL string that can be used in models:
```jinja2
{% macro adapter__get_query_history(...) %}
    select
        query_id,
        query_text,
        user_name,
        -- ... standard columns
    from system.query_history
    where ...
{% endmacro %}
```

### print_* macros
Execute query and print results:
```jinja2
{% macro adapter__print_query_history(...) %}
    {# Set self-identifier first #}
    {% do run_query("/* " ~ dbt_query_profiler._self_identifier() ~ " */ SELECT 1") %}

    {% set query %}
        select array_agg(object_construct(*)) as result
        from ({{ dbt_query_profiler.get_query_history(...) }})
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute and results and results.rows and results.rows[0][0] %}
        {{ print(results.rows[0][0]) }}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ print("No query found") }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
```

## Unsupported Features

If a feature isn't available for the adapter, raise a clear error:

```jinja2
{% macro adapter__get_query_plan(query_id, format) %}
    {{ exceptions.raise_compiler_error(
        "get_query_plan is not supported for " ~ target.type ~
        ". This adapter does not expose query execution plans."
    ) }}
{% endmacro %}
```

## Documentation Updates

### README.md
1. **Feature matrix** (lines 7-12): Add row for new adapter
2. **Permissions section**: Add subsection with required grants/roles
3. **Platform-Specific Notes**: Add subsection with behaviors, limitations, retention periods

### macros/schema.yml
Add adapter name to "Supported adapters:" in each macro description:
```yaml
- name: get_query_history
  description: |
    ...
    **Supported adapters:** Snowflake, BigQuery, Databricks, Redshift, DuckDB, {NewAdapter}
```

## Integration Tests

### Location
```
integration_tests/
├── models/setup/
│   └── setup_{adapter}.sql      # If special initialization needed
├── tests/
│   └── (existing tests work via dispatch)
└── dbt_project.yml              # Update if hooks needed
```

### Conditional Test Execution
If a feature isn't supported, disable tests for that adapter:
```jinja2
{{
    config(
        enabled=(target.type != 'your_adapter')
    )
}}
```

### Setup Model (if needed)
Some adapters require initialization (like DuckDB's logging):
```jinja2
-- models/setup/setup_adapter.sql
{{
    config(
        materialized='table',
        tags=['setup']
    )
}}

{% if execute %}
    {% do run_query("ADAPTER_SPECIFIC_SETUP_COMMAND") %}
{% endif %}

select 1 as setup_complete
```

### On-Run-Start Hooks
Add to `integration_tests/dbt_project.yml` if needed:
```yaml
on-run-start:
  - "{{ dbt_query_profiler_integration_tests.enable_adapter_feature() }}"
```

## Quick Reference: System Tables by Adapter

| Adapter | Query History Source |
|---------|---------------------|
| Snowflake | `information_schema.query_history()` or `snowflake.account_usage.query_history` |
| BigQuery | `INFORMATION_SCHEMA.JOBS_BY_USER` or `JOBS_BY_PROJECT` |
| Databricks | `system.query.history` |
| Redshift | `sys_query_history` |
| DuckDB | `duckdb_logs` (requires `CALL enable_logging('QueryLog')`) |

## Checklist for New Adapter

- [ ] Create `macros/{adapter}/query_history.sql` with get_ and print_ macros
- [ ] Create `macros/{adapter}/query_sql.sql` with get_ and print_ macros
- [ ] Create `macros/{adapter}/query_plan.sql` with get_ and print_ macros (EXPLAIN-based, or raise error)
- [ ] Create `macros/{adapter}/execution_plan.sql` with get_, print_, and summary macros (or raise error)
- [ ] Create `macros/{adapter}/query_stats.sql` with get_ and print_ macros
- [ ] Implement `_self_identifier()` exclusion in all get_ macros
- [ ] Add self-identifier tagging/commenting in all print_ macros
- [ ] Update README.md feature matrix
- [ ] Update README.md permissions section
- [ ] Update README.md platform-specific notes
- [ ] Update macros/schema.yml supported adapters lists
- [ ] Add setup model if adapter needs initialization
- [ ] Disable unsupported tests with `config(enabled=...)`
- [ ] Test with `dbt run-operation dbt_query_profiler.print_query_history`
