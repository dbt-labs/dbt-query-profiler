{% macro get_query_sql(query_id) %}
    {{ return(adapter.dispatch('get_query_sql', 'dbt_query_profiler')(query_id=query_id)) }}
{% endmacro %}


{% macro default__get_query_sql(query_id) %}
    {{ exceptions.raise_compiler_error("get_query_sql is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_sql(query_id) %}
    {{ return(adapter.dispatch('print_query_sql', 'dbt_query_profiler')(query_id=query_id)) }}
{% endmacro %}


{% macro default__print_query_sql(query_id) %}
    {{ exceptions.raise_compiler_error("print_query_sql is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}
