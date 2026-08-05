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
    The node id as dbt's query comment writes it, including the key: `"node_id": "<id>"`.

    Limitation: this depends on dbt's `": "` key/value separator. Matching the bare quoted
    id instead would avoid that, but then any query merely *mentioning* an id matches, and
    since selection ranks by duration a slow query about a model can outrank the model's
    own build. Requiring the key trades a silent wrong answer for a loud one - if dbt's
    query_comment format ever changes, resolution fails visibly in the tests.
#}
{% macro _node_id_needle(node_id) %}{{ return('"node_id": "' ~ node_id ~ '"') }}{% endmacro %}


{#
    A "column contains this literal text" predicate, as SQL.

    Exists because the adapters disagree on the spelling: BigQuery has no
    `POSITION(x IN y)` and needs `STRPOS(y, x)`. Every history filter needs this, so
    without a helper each filter has to remember the BigQuery exception separately.
    The needle is escaped here; callers pass it raw.
#}
{% macro contains_text(column, needle) %}
    {{ return(adapter.dispatch('contains_text', 'dbt_query_profiler')(column=column, needle=needle)) }}
{% endmacro %}


{% macro default__contains_text(column, needle) %}
    {{ return("position('" ~ dbt_query_profiler._escape_literal(needle) ~ "' in " ~ column ~ ") > 0") }}
{% endmacro %}


{% macro bigquery__contains_text(column, needle) %}
    {{ return("strpos(" ~ column ~ ", '" ~ dbt_query_profiler._escape_literal(needle) ~ "') > 0") }}
{% endmacro %}

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
