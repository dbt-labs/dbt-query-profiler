{#
    Test: get_query_plan with SQL returns an EXPLAIN plan.

    This tests the new SQL-based query plan that doesn't require query history access.
    Note: BigQuery does not support EXPLAIN, so this test is skipped.

    We test by running the EXPLAIN via run_query in Jinja and verifying it returns results.
    This avoids issues with EXPLAIN not being valid in CTEs in some SQL dialects.
#}

{{ config(enabled=(target.type != 'bigquery')) }}

{# Run EXPLAIN via Jinja and check results #}
{% set test_sql = "SELECT 1 as test_col" %}
{% set plan_sql = dbt_query_profiler.get_query_plan(sql=test_sql) %}

{% if execute %}
    {% set results = run_query(plan_sql) %}
    {% if not results or not results.rows or results.rows | length == 0 %}
        {{ exceptions.raise_compiler_error("EXPLAIN returned no results for test query") }}
    {% endif %}
{% endif %}

-- If we get here, the test passed. Return empty result set (no failures).
select 'placeholder' as failure_reason where 1=0
