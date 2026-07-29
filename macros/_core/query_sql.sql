{% macro get_query_sql(query_id=none, result_limit=1000, model_name=none, node_id=none, num_candidates=10) %}
    {%- set resolved = dbt_query_profiler.resolve_query_id(query_id, model_name, node_id, num_candidates) -%}
    {{ return(adapter.dispatch('get_query_sql', 'dbt_query_profiler')(query_id=resolved, result_limit=result_limit)) }}
{% endmacro %}


{% macro default__get_query_sql(query_id, result_limit=1000) %}
    {{ exceptions.raise_compiler_error("get_query_sql is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_sql(query_id=none, result_limit=1000, model_name=none, node_id=none, num_candidates=10) %}
    {%- set resolved = dbt_query_profiler.resolve_query_id(query_id, model_name, node_id, num_candidates) -%}
    {{ return(adapter.dispatch('print_query_sql', 'dbt_query_profiler')(query_id=resolved, result_limit=result_limit)) }}
{% endmacro %}


{% macro default__print_query_sql(query_id, result_limit=1000) %}
    {{ exceptions.raise_compiler_error("print_query_sql is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}
