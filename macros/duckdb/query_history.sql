{% macro duckdb__ensure_logging_enabled() %}
    {#
        Enable DuckDB logging with file-based storage.
        File storage is required for logs to persist across sessions.
        This must be called at the start of print_* macros that read from duckdb_logs.
    #}
    {% if execute %}
        {% set log_path = var('duckdb_log_storage_path', 'target/duckdb_query_logs') %}
        {% do run_query("CALL enable_logging('QueryLog', storage_path = '" ~ log_path ~ "');") %}
    {% endif %}
{% endmacro %}


{% macro duckdb__query_log_lookup(query_id) %}
    {#
        Resolve a query_id handed out by duckdb__get_query_history back to its SQL text.

        query_id is a composite "<context_id>:<epoch_us>". Neither column alone
        identifies a query: context_id is per-execution-context and
        duckdb_logs.query_id is a per-connection counter, so both recycle once
        file-based logs accumulate across sessions and one value then covers many
        unrelated statements. Only the pair (context_id, epoch_us(timestamp)) is
        unique - do not simplify this back to a single column.

        DuckDB writes one identical log row per connection, so `limit 1` here picks
        among true duplicates of the same statement.
    #}
    {%- set parts = (query_id | string).split(':') -%}
    {%- if parts | length != 2 or not parts[0].isdigit() or not parts[1].isdigit() -%}
        {{ exceptions.raise_compiler_error(
            "Invalid DuckDB query_id: '" ~ query_id ~ "'. Expected '<context_id>:<epoch_us>' "
            ~ "as returned by get_query_history, e.g. '82:1785233290416576'."
        ) }}
    {%- endif %}
    /* {{ dbt_query_profiler._self_identifier() }} */
    select message
    from duckdb_logs
    where type = 'QueryLog'
        and context_id = {{ parts[0] }}
        and epoch_us(timestamp) = {{ parts[1] }}
    limit 1
{% endmacro %}


{% macro duckdb__get_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {# DuckDB requires logging to be enabled with: CALL enable_logging('QueryLog'); #}
    {#
        DISTINCT is required: DuckDB logs each statement once per connection, so
        without it `limit N` returns N copies of the same query.

        query_id is a composite of context_id and the microsecond timestamp —
        see duckdb__query_log_lookup for why neither column works alone.
    #}
    select distinct
        context_id::varchar || ':' || epoch_us(timestamp)::varchar as query_id,
        message as query_text,
        cast(null as varchar) as user_name,
        cast(null as varchar) as warehouse_name,
        cast(null as varchar) as query_type,
        cast(null as varchar) as query_tag,
        timestamp as start_time,
        cast(null as bigint) as total_elapsed_time
    from duckdb_logs
    where type = 'QueryLog'
        and position('{{ dbt_query_profiler._self_identifier() }}' in message) = 0
    {% if table_name %}
        and position(lower('{{ dbt_query_profiler._escape_literal(table_name) }}') in lower(message)) > 0
    {% endif %}
    {% if node_id %}
        and position('{{ dbt_query_profiler._escape_literal(node_id) }}' in message) > 0
    {% endif %}
    order by start_time desc
    limit {{ limit }}
{% endmacro %}


{% macro duckdb__print_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {{ duckdb__ensure_logging_enabled() }}
    {% set query %}
        /* {{ dbt_query_profiler._self_identifier() }} */
        select list(
            {
                'query_id': query_id,
                'user_name': user_name,
                'warehouse_name': warehouse_name,
                'query_type': query_type,
                'query_tag': query_tag,
                'start_time': start_time::varchar,
                'total_elapsed_time': total_elapsed_time,
                'query_text': query_text
            }
            order by start_time desc
        )::json as result
        from ({{ dbt_query_profiler.get_query_history(table_name=table_name, user_name=user_name, query_type=query_type, limit=limit, result_limit=result_limit, node_id=node_id) }})
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute and results and results.rows and results.rows[0][0] %}
        {{ print(results.rows[0][0]) }}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ print("No query found. Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
