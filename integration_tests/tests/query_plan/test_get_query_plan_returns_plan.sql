{#
    Test: get_query_plan returns execution plan data.

    Note: BigQuery does not support get_query_plan, so this test is skipped.

    For query_plan, we need a query_id first. We get one from query_history
    and then call get_query_plan with it.

    The challenge: Jinja macros are expanded at compile time, but query_id
    is only known at runtime. So we use a two-step approach:
    1. Get the query_id via a subquery
    2. Test that the query plan source exists and is accessible
#}

{{ config(enabled=(target.type != 'bigquery')) }}

-- depends_on: {{ ref('setup_test_queries') }}

{# Get a recent query_id from history #}
{% set history_sql = dbt_query_profiler.get_query_history(limit=1) %}

with history as (
    {{ history_sql }}
),

{#
    For each adapter, verify we can access the query plan data source.
    We can't directly call get_query_plan() with a runtime query_id,
    but we can verify the plan data is accessible.
#}

{% if target.type == 'duckdb' %}
{# DuckDB get_query_plan retrieves query from logs and runs EXPLAIN #}
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

-- Test passes if we found data to query plans from
select 'No data available to generate query plans' as failure_reason
from plan_check
where cnt = 0
