{% macro databricks__get_query_stats(query_id, result_limit) %}
    select
        statement_id as query_id,
        statement_type as query_type,
        executed_by as user_name,
        compute.warehouse_id as warehouse_name,
        cast(null as string) as warehouse_size,
        execution_status,
        total_duration_ms as execution_time_ms,
        read_bytes as bytes_scanned,
        written_bytes as bytes_written,
        produced_rows as rows_produced,
        read_rows,
        read_files,
        read_partitions,
        pruned_files,
        compilation_duration_ms,
        execution_duration_ms,
        waiting_for_compute_duration_ms as queue_time_ms,
        waiting_at_capacity_duration_ms as queue_capacity_time_ms,
        result_fetch_duration_ms,
        total_task_duration_ms,
        read_io_cache_percent,
        from_result_cache,
        spilled_local_bytes,
        shuffle_read_bytes
    from system.query.history
    where statement_id = '{{ query_id }}'
{% endmacro %}


{% macro databricks__print_query_stats(query_id, format, result_limit) %}

    {% if format == 'text' %}
        {% set query %}
            select
                statement_id,
                execution_status,
                total_duration_ms,
                read_bytes,
                produced_rows,
                written_bytes,
                from_result_cache
            from system.query.history
            where statement_id = '{{ query_id }}'
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% set row = results.rows[0] %}
            {{ print("Query ID:     " ~ row[0]) }}
            {{ print("Status:       " ~ row[1]) }}
            {{ print("Duration:     " ~ row[2] ~ " ms") }}
            {{ print("Bytes Read:   " ~ (row[3] if row[3] else '-')) }}
            {{ print("Rows:         " ~ (row[4] if row[4] else '-')) }}
            {{ print("Bytes Out:    " ~ (row[5] if row[5] else '-')) }}
            {{ print("Cache Hit:    " ~ row[6]) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}

    {% else %}
        {# JSON format #}
        {% set query %}
            select to_json(struct(
                statement_id as query_id,
                statement_type as query_type,
                executed_by as user_name,
                compute.warehouse_id as warehouse_name,
                execution_status,
                total_duration_ms as execution_time_ms,
                read_bytes as bytes_scanned,
                written_bytes as bytes_written,
                produced_rows as rows_produced,
                read_rows,
                compilation_duration_ms,
                execution_duration_ms,
                waiting_for_compute_duration_ms as queue_time_ms,
                from_result_cache as cache_hit,
                spilled_local_bytes,
                shuffle_read_bytes
            )) as stats
            from system.query.history
            where statement_id = '{{ query_id }}'
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}
    {% endif %}
{% endmacro %}
