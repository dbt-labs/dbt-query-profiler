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


{% macro duckdb__get_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {# DuckDB requires logging to be enabled with: CALL enable_logging('QueryLog'); #}
    select
        query_id,
        message as query_text,
        cast(null as varchar) as user_name,
        cast(null as varchar) as warehouse_name,
        cast(null as varchar) as query_type,
        cast(null as varchar) as query_tag,
        timestamp as start_time,
        cast(null as bigint) as total_elapsed_time
    from duckdb_logs
    where type = 'QueryLog'
        and message not like '%{{ dbt_query_profiler._self_identifier() }}%'
    {% if table_name %}
        and lower(message) like '%{{ table_name | lower }}%'
    {% endif %}
    order by timestamp desc
    limit {{ limit }}
{% endmacro %}


{% macro duckdb__print_query_history(table_name, user_name, query_type, limit, result_limit) %}
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
        from ({{ dbt_query_profiler.get_query_history(table_name=table_name, user_name=user_name, query_type=query_type, limit=limit, result_limit=result_limit) }})
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
