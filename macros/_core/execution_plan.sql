{% macro get_execution_plan(query_id) %}
    {{ return(adapter.dispatch('get_execution_plan', 'dbt_query_profiler')(query_id=query_id)) }}
{% endmacro %}


{% macro default__get_execution_plan(query_id) %}
    {{ exceptions.raise_compiler_error("get_execution_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_execution_plan(query_id, format='json') %}
    {{ return(adapter.dispatch('print_execution_plan', 'dbt_query_profiler')(query_id=query_id, format=format)) }}
{% endmacro %}


{% macro default__print_execution_plan(query_id, format) %}
    {{ exceptions.raise_compiler_error("print_execution_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro get_execution_plan_summary(query_id) %}
    {{ return(adapter.dispatch('get_execution_plan_summary', 'dbt_query_profiler')(query_id=query_id)) }}
{% endmacro %}


{% macro default__get_execution_plan_summary(query_id) %}
    {{ exceptions.raise_compiler_error("get_execution_plan_summary is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}
