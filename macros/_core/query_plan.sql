{% macro get_query_plan(sql) %}
    {{ return(adapter.dispatch('get_query_plan', 'dbt_query_profiler')(sql=sql)) }}
{% endmacro %}


{% macro default__get_query_plan(sql) %}
    {{ exceptions.raise_compiler_error("get_query_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_plan(sql, format='text') %}
    {{ return(adapter.dispatch('print_query_plan', 'dbt_query_profiler')(sql=sql, format=format)) }}
{% endmacro %}


{% macro default__print_query_plan(sql, format) %}
    {{ exceptions.raise_compiler_error("print_query_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}
