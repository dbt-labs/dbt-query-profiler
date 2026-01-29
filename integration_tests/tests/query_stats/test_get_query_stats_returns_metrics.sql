{#
    Test: get_query_stats returns execution statistics.

    Note for DuckDB: get_query_stats will re-execute the query via EXPLAIN ANALYZE.

    Similar to query_plan, we can't pass a runtime query_id to a compile-time macro.
    This test verifies that:
    1. Query history is accessible (via get_query_history macro)
    2. The stats data source exists for the adapter
#}

-- depends_on: {{ ref('setup_test_queries') }}

{# Get recent queries using the actual macro #}
{% set history_sql = dbt_query_profiler.get_query_history(limit=5) %}

with history as (
    {{ history_sql }}
),

{% if target.type == 'duckdb' %}
{# DuckDB: Stats come from EXPLAIN ANALYZE on query from logs. Verify logs exist. #}
stats_check as (
    select count(*) as cnt
    from duckdb_logs
    where type = 'QueryLog'
)
{% elif target.type == 'snowflake' %}
{# Snowflake: Stats come from query_history. Verify columns exist. #}
stats_check as (
    select count(*) as cnt
    from history
    where query_id is not null
)
{% elif target.type == 'bigquery' %}
{# BigQuery: Stats come from JOBS_BY_USER #}
stats_check as (
    select count(*) as cnt
    from history
    where query_id is not null
)
{% elif target.type == 'databricks' %}
{# Databricks: Stats from system.query.history #}
stats_check as (
    select count(*) as cnt
    from history
    where query_id is not null
)
{% elif target.type == 'redshift' %}
{# Redshift: Stats from sys_query_history #}
stats_check as (
    select count(*) as cnt
    from history
    where query_id is not null
)
{% else %}
stats_check as (
    select 1 as cnt
)
{% endif %}

-- Test passes if we found queries with stats
select 'No queries found to retrieve stats from' as failure_reason
from stats_check
where cnt = 0
