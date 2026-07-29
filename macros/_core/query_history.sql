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

{#
    The node id as it appears in dbt's query comment, keyed: `"node_id": "<node_id>"`.

    Anchoring on the surrounding double quotes alone (the previous form of this macro)
    cannot tell "the query comment names this node" from "the query text happens to
    mention the id in double quotes" - and because statement selection ranks candidates
    by duration, a slow query that merely *mentions* a node id can outrank that node's own
    (usually much faster) build, which is a silent wrong answer, not a loud one. Confirmed
    live on Redshift: a 5.7s hand-written diagnostic query that only mentioned a node id
    outranked the node's actual 227ms CTAS until the key was added to the needle.

    Depending on dbt's `": "` key/value separator is a real risk - if dbt ever changes its
    query_comment JSON formatting, this breaks. It's the preferable risk of the two:
    a formatting change fails resolution loudly (on all five adapters at once, in the
    regression tests), where the bug this replaces failed silently (profiling the wrong
    statement with no error). The `": "` spacing was observed consistent across all five
    supported adapters, on both dbt-core and dbt-fusion.
#}
{% macro _node_id_needle(node_id) %}{{ return('"node_id": "' ~ node_id ~ '"') }}{% endmacro %}

{% macro get_query_history(table_name=none, user_name=none, query_type=none, limit=1, result_limit=100, node_id=none, model_name=none) %}
    {%- set resolved_node_id = dbt_query_profiler._resolve_history_node_id(model_name, node_id) -%}
    {{ return(adapter.dispatch('get_query_history', 'dbt_query_profiler')(
        table_name=table_name,
        user_name=user_name,
        query_type=query_type,
        limit=limit,
        result_limit=result_limit,
        node_id=resolved_node_id
    )) }}
{% endmacro %}


{% macro default__get_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {{ exceptions.raise_compiler_error("get_query_history is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_history(table_name=none, user_name=none, query_type=none, limit=1, result_limit=100, node_id=none, model_name=none) %}
    {%- set resolved_node_id = dbt_query_profiler._resolve_history_node_id(model_name, node_id) -%}
    {{ return(adapter.dispatch('print_query_history', 'dbt_query_profiler')(
        table_name=table_name,
        user_name=user_name,
        query_type=query_type,
        limit=limit,
        result_limit=result_limit,
        node_id=resolved_node_id
    )) }}
{% endmacro %}


{% macro default__print_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {{ exceptions.raise_compiler_error("print_query_history is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, bigquery, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro ensure_history_available() %}
    {{ return(adapter.dispatch('ensure_history_available', 'dbt_query_profiler')()) }}
{% endmacro %}


{#
    Most adapters expose query history with no setup. DuckDB needs logging switched on,
    and `dbt run-operation` does not fire the on-run-start hook that normally does it.
#}
{% macro default__ensure_history_available() %}
{% endmacro %}
