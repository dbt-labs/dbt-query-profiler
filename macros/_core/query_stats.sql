{% macro get_query_stats(query_id, result_limit=10000) %}
    {{ return(adapter.dispatch('get_query_stats', 'dbt_query_profiler')(query_id=query_id, result_limit=result_limit)) }}
{% endmacro %}


{% macro default__get_query_stats(query_id, result_limit) %}
    {{ exceptions.raise_compiler_error("get_query_stats is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_stats(query_id, format='json', result_limit=10000) %}
    {{ return(adapter.dispatch('print_query_stats', 'dbt_query_profiler')(query_id=query_id, format=format, result_limit=result_limit)) }}
{% endmacro %}


{% macro default__print_query_stats(query_id, format, result_limit) %}
    {{ exceptions.raise_compiler_error("print_query_stats is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}
