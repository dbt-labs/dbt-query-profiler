{#
    Test: get_query_plan with SQL returns an EXPLAIN plan.

    This tests the new SQL-based query plan that doesn't require query history access.
    Note: BigQuery does not support EXPLAIN, so this test is skipped.
#}

{{ config(enabled=(target.type != 'bigquery')) }}

{# Generate a simple EXPLAIN plan #}
{% set test_sql = "SELECT 1 as test_col" %}
{% set plan_sql = dbt_query_profiler.get_query_plan(sql=test_sql) %}

with plan_result as (
    {{ plan_sql }}
)

-- Test passes if EXPLAIN returned at least one row
select 'EXPLAIN returned no results' as failure_reason
where not exists (select 1 from plan_result)
