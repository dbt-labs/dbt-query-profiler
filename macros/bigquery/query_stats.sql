{% macro bigquery__get_query_stats(query_id, result_limit) %}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select
        job_id as query_id,
        statement_type as query_type,
        user_email as user_name,
        cast(null as string) as warehouse_name,
        cast(null as string) as warehouse_size,
        state as execution_status,
        timestamp_diff(end_time, start_time, millisecond) as execution_time_ms,
        total_bytes_processed as bytes_scanned,
        destination_table.table_id is not null as has_destination,
        total_bytes_billed as bytes_billed,
        cache_hit,
        total_slot_ms as slot_ms,
        bi_engine_statistics.bi_engine_mode as bi_engine_mode,
        dml_statistics.inserted_row_count as rows_inserted,
        dml_statistics.updated_row_count as rows_updated,
        dml_statistics.deleted_row_count as rows_deleted,
        query_info.resource_warning as resource_warning,
        transferred_bytes,
        total_bytes_processed_accuracy
    {% if use_account_level %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
    {% else %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_USER
    {% endif %}
    where job_id = '{{ query_id }}'
{% endmacro %}


{% macro bigquery__print_query_stats(query_id, format, result_limit) %}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}
    {%- set jobs_table = 'JOBS_BY_PROJECT' if use_account_level else 'JOBS_BY_USER' -%}

    {% if format == 'text' %}
        {% set query %}
            select
                job_id,
                state,
                timestamp_diff(end_time, start_time, millisecond) as duration_ms,
                total_bytes_processed,
                total_bytes_billed,
                cache_hit,
                total_slot_ms
            from `region-{{ region }}`.INFORMATION_SCHEMA.{{ jobs_table }}
            where job_id = '{{ query_id }}'
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% set row = results.rows[0] %}
            {{ print("Query ID:     " ~ row[0]) }}
            {{ print("Status:       " ~ row[1]) }}
            {{ print("Duration:     " ~ row[2] ~ " ms") }}
            {{ print("Bytes Read:   " ~ (row[3] if row[3] else '-')) }}
            {{ print("Bytes Billed: " ~ (row[4] if row[4] else '-')) }}
            {{ print("Cache Hit:    " ~ row[5]) }}
            {{ print("Slot MS:      " ~ (row[6] if row[6] else '-')) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}

    {% else %}
        {# JSON format #}
        {% set query %}
            select to_json_string(struct(
                job_id as query_id,
                statement_type as query_type,
                user_email as user_name,
                state as execution_status,
                timestamp_diff(end_time, start_time, millisecond) as execution_time_ms,
                total_bytes_processed as bytes_scanned,
                total_bytes_billed as bytes_billed,
                cache_hit,
                total_slot_ms as slot_ms,
                bi_engine_statistics.bi_engine_mode as bi_engine_mode,
                dml_statistics.inserted_row_count as rows_inserted,
                dml_statistics.updated_row_count as rows_updated,
                dml_statistics.deleted_row_count as rows_deleted,
                query_info.resource_warning as resource_warning
            )) as stats
            from `region-{{ region }}`.INFORMATION_SCHEMA.{{ jobs_table }}
            where job_id = '{{ query_id }}'
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}
    {% endif %}
{% endmacro %}
