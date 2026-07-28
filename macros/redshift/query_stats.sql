{% macro redshift__get_query_stats(query_id, result_limit) %}
    {%- set custom_source = var('redshift_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'sys_query_history' -%}
    select
        query_id,
        query_type,
        username as user_name,
        database_name as warehouse_name,
        cast(null as varchar) as warehouse_size,
        status as execution_status,
        elapsed_time / 1000 as execution_time_ms,
        returned_bytes as bytes_scanned,
        returned_bytes as bytes_written_to_result,
        returned_rows as rows_produced,
        compile_time / 1000 as compilation_time_ms,
        execution_time / 1000 as execution_time_only_ms,
        queue_time / 1000 as queue_time_ms,
        planning_time / 1000 as planning_time_ms,
        lock_wait_time / 1000 as lock_wait_time_ms,
        result_cache_hit
    from {{ source_table }}
    where query_id = {{ query_id }}
{% endmacro %}


{% macro redshift__print_query_stats(query_id, format, result_limit) %}
    {%- set custom_source = var('redshift_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'sys_query_history' -%}

    {% if format == 'text' %}
        {% set query %}
            select
                query_id,
                status,
                elapsed_time / 1000 as duration_ms,
                returned_bytes,
                returned_rows,
                result_cache_hit
            from {{ source_table }}
            where query_id = {{ query_id }}
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% set row = results.rows[0] %}
            {{ print("Query ID:     " ~ row[0]) }}
            {{ print("Status:       " ~ row[1]) }}
            {{ print("Duration:     " ~ row[2] ~ " ms") }}
            {{ print("Bytes Out:    " ~ (row[3] if row[3] else '-')) }}
            {{ print("Rows:         " ~ (row[4] if row[4] else '-')) }}
            {{ print("Cache Hit:    " ~ row[5]) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}

    {% else %}
        {# JSON format #}
        {% set query %}
            select json_serialize(
                object(
                    'query_id', query_id,
                    'query_type', query_type,
                    'user_name', username,
                    'database_name', database_name,
                    'execution_status', status,
                    'execution_time_ms', elapsed_time / 1000,
                    'returned_bytes', returned_bytes,
                    'returned_rows', returned_rows,
                    'compilation_time_ms', compile_time / 1000,
                    'execution_time_only_ms', execution_time / 1000,
                    'queue_time_ms', queue_time / 1000,
                    'planning_time_ms', planning_time / 1000,
                    'result_cache_hit', result_cache_hit
                )
            ) as stats
            from {{ source_table }}
            where query_id = {{ query_id }}
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}
    {% endif %}
{% endmacro %}
