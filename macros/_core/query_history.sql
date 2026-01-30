{% macro _self_identifier() %}__dbt_query_profiler_self__{% endmacro %}

{% macro get_query_history(table_name=none, user_name=none, query_type=none, limit=1, result_limit=100) %}
    {{ return(adapter.dispatch('get_query_history', 'dbt_query_profiler')(
        table_name=table_name,
        user_name=user_name,
        query_type=query_type,
        limit=limit,
        result_limit=result_limit
    )) }}
{% endmacro %}


{% macro default__get_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {{ exceptions.raise_compiler_error("get_query_history is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_history(table_name=none, user_name=none, query_type=none, limit=1, result_limit=100) %}
    {{ return(adapter.dispatch('print_query_history', 'dbt_query_profiler')(
        table_name=table_name,
        user_name=user_name,
        query_type=query_type,
        limit=limit,
        result_limit=result_limit
    )) }}
{% endmacro %}


{% macro default__print_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {{ exceptions.raise_compiler_error("print_query_history is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}
