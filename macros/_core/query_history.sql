{% macro _self_identifier() %}__dbt_query_profiler_self__{% endmacro %}

{#
    Escape a value for safe interpolation inside a single-quoted SQL literal.

    Doubling the single quote is the ANSI-standard escape and works on all five
    supported adapters. Without this, a table_name containing an apostrophe
    produces a syntax error (or worse).

    Returns the *inner* text only - callers still wrap it in quotes. Kept on one
    line: any whitespace inside the macro body ends up inside the SQL literal.
#}
{% macro _escape_literal(value) %}{{ (value | string).replace("'", "''") }}{% endmacro %}

{% macro get_query_history(table_name=none, user_name=none, query_type=none, limit=1, result_limit=100, node_id=none) %}
    {{ return(adapter.dispatch('get_query_history', 'dbt_query_profiler')(
        table_name=table_name,
        user_name=user_name,
        query_type=query_type,
        limit=limit,
        result_limit=result_limit,
        node_id=node_id
    )) }}
{% endmacro %}


{% macro default__get_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {{ exceptions.raise_compiler_error("get_query_history is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_history(table_name=none, user_name=none, query_type=none, limit=1, result_limit=100, node_id=none) %}
    {{ return(adapter.dispatch('print_query_history', 'dbt_query_profiler')(
        table_name=table_name,
        user_name=user_name,
        query_type=query_type,
        limit=limit,
        result_limit=result_limit,
        node_id=node_id
    )) }}
{% endmacro %}


{% macro default__print_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {{ exceptions.raise_compiler_error("print_query_history is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}
