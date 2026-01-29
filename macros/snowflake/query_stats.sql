{% macro snowflake__get_query_stats(query_id, result_limit) %}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select
        query_id,
        query_type,
        user_name,
        warehouse_name,
        warehouse_size,
        execution_status,
        total_elapsed_time as execution_time_ms,
        bytes_scanned,
        bytes_written_to_result,
        rows_produced,
        credits_used_cloud_services,
        compilation_time as compilation_time_ms,
        execution_time as execution_time_only_ms,
        queued_provisioning_time as queue_time_ms,
        queued_overload_time as queue_overload_time_ms
    {% if use_account_level %}
    from snowflake.account_usage.query_history
    {% else %}
    from table(information_schema.query_history(result_limit => {{ result_limit }}))
    {% endif %}
    where query_id = '{{ query_id }}'
{% endmacro %}


{% macro snowflake__print_query_stats(query_id, format, result_limit) %}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    {% if format == 'text' %}
        {% set query %}
            select
                query_id,
                execution_status,
                total_elapsed_time,
                bytes_scanned,
                rows_produced,
                bytes_written_to_result
            {% if use_account_level %}
            from snowflake.account_usage.query_history
            {% else %}
            from table(information_schema.query_history(result_limit => {{ result_limit }}))
            {% endif %}
            where query_id = '{{ query_id }}'
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
        {% else %}
            {{ print("Query not found") }}
        {% endif %}

    {% else %}
        {# JSON format #}
        {% set query %}
            select object_construct(
                'query_id', query_id,
                'query_type', query_type,
                'user_name', user_name,
                'warehouse_name', warehouse_name,
                'warehouse_size', warehouse_size,
                'execution_status', execution_status,
                'execution_time_ms', total_elapsed_time,
                'bytes_scanned', bytes_scanned,
                'bytes_written_to_result', bytes_written_to_result,
                'rows_produced', rows_produced,
                'compilation_time_ms', compilation_time,
                'execution_time_only_ms', execution_time,
                'queue_time_ms', queued_provisioning_time
            ) as stats
            {% if use_account_level %}
            from snowflake.account_usage.query_history
            {% else %}
            from table(information_schema.query_history(result_limit => {{ result_limit }}))
            {% endif %}
            where query_id = '{{ query_id }}'
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("Query not found") }}
        {% endif %}
    {% endif %}
{% endmacro %}
