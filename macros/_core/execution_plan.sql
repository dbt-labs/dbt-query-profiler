{% macro get_execution_plan(query_id=none, model_name=none, node_id=none, num_candidates=10, result_limit=100) %}
    {%- set resolved = dbt_query_profiler.resolve_query_id(query_id=query_id, model_name=model_name, node_id=node_id, num_candidates=num_candidates, result_limit=result_limit) -%}
    {{ return(adapter.dispatch('get_execution_plan', 'dbt_query_profiler')(query_id=resolved)) }}
{% endmacro %}


{% macro default__get_execution_plan(query_id) %}
    {{ exceptions.raise_compiler_error("get_execution_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_execution_plan(query_id=none, format='json', model_name=none, node_id=none, num_candidates=10, result_limit=100) %}
    {%- set resolved = dbt_query_profiler.resolve_query_id(query_id=query_id, model_name=model_name, node_id=node_id, num_candidates=num_candidates, result_limit=result_limit) -%}
    {{ return(adapter.dispatch('print_execution_plan', 'dbt_query_profiler')(query_id=resolved, format=format)) }}
{% endmacro %}


{% macro default__print_execution_plan(query_id, format) %}
    {{ exceptions.raise_compiler_error("print_execution_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro get_execution_plan_summary(query_id=none, model_name=none, node_id=none, num_candidates=10, result_limit=100) %}
    {%- set resolved = dbt_query_profiler.resolve_query_id(query_id=query_id, model_name=model_name, node_id=node_id, num_candidates=num_candidates, result_limit=result_limit) -%}
    {{ return(adapter.dispatch('get_execution_plan_summary', 'dbt_query_profiler')(query_id=resolved)) }}
{% endmacro %}


{% macro default__get_execution_plan_summary(query_id) %}
    {{ exceptions.raise_compiler_error("get_execution_plan_summary is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}
