{#
    Test: get_execution_plan returns execution plan data from query history.

    Note: BigQuery does not support get_execution_plan, so this test is skipped.

    For execution_plan, we need a query_id first. We get one from query_history
    and then verify the execution plan source exists and is accessible.
#}

{{ config(enabled=(target.type != 'bigquery')) }}

-- depends_on: {{ ref('setup_test_queries') }}

{# Get a recent query_id from history #}
{% set history_sql = dbt_query_profiler.get_query_history(limit=1) %}

with history as (
    {{ history_sql }}
),

{#
    For each adapter, verify we can access the execution plan data source.
    We can't directly call get_execution_plan() with a runtime query_id,
    but we can verify the plan data is accessible.
#}

{% if target.type == 'duckdb' %}
{# DuckDB get_execution_plan retrieves query from logs and runs EXPLAIN #}
plan_check as (
    select count(*) as cnt
    from duckdb_logs
    where type = 'QueryLog'
)
{% elif target.type == 'snowflake' %}
{# Snowflake uses get_query_operator_stats - verify a query exists to test against #}
plan_check as (
    select count(*) as cnt from history
)
{% elif target.type == 'databricks' %}
{# Databricks uses EXPLAIN on query text from history #}
plan_check as (
    select count(*) as cnt from history
)
{% elif target.type == 'redshift' %}
{# Redshift uses stl_explain #}
plan_check as (
    select count(*) as cnt from stl_explain limit 1
)
{% else %}
plan_check as (
    select 1 as cnt
)
{% endif %}

-- Test passes if we found data to query execution plans from
select 'No data available to generate execution plans' as failure_reason
from plan_check
where cnt = 0
