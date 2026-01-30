{% macro assert_rows_returned(sql_statement, min_rows=1, description='') %}
    {#
        Assert that a SQL statement returns at least min_rows rows.
        Used in singular tests to verify macro output.
    #}
    {% set results = run_query(sql_statement) %}
    {% set row_count = results.rows | length if results and results.rows else 0 %}

    {% if row_count < min_rows %}
        {{ exceptions.raise_compiler_error(
            "Assertion failed" ~ (": " ~ description if description else "") ~
            ". Expected at least " ~ min_rows ~ " row(s), got " ~ row_count
        ) }}
    {% endif %}

    {{ return(results) }}
{% endmacro %}


{% macro assert_column_exists(results, column_name, description='') %}
    {#
        Assert that a result set contains a specific column.
    #}
    {% set columns = results.columns | map(attribute='name') | map('lower') | list %}

    {% if column_name | lower not in columns %}
        {{ exceptions.raise_compiler_error(
            "Assertion failed" ~ (": " ~ description if description else "") ~
            ". Expected column '" ~ column_name ~ "' not found. Available: " ~ columns | join(', ')
        ) }}
    {% endif %}
{% endmacro %}


{% macro get_test_query_id() %}
    {#
        Get a query_id from query history that matches our test marker.
        This is used to test query_sql, query_plan, and query_stats macros.
    #}
    {% set history_sql = dbt_query_profiler.get_query_history(
        table_name=var('test_marker'),
        limit=1
    ) %}

    {% set results = run_query(history_sql) %}

    {% if execute and results and results.rows and results.rows | length > 0 %}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ exceptions.raise_compiler_error("No test query found in history. Run setup models first.") }}
    {% endif %}
{% endmacro %}


{% macro enable_duckdb_logging() %}
    {#
        Enable DuckDB query logging with file-based storage if running on DuckDB.
        Called via on-run-start hook.

        File-based storage is required for logs to persist across sessions,
        which is needed for run-operation tests to work.
    #}
    {% if target.type == 'duckdb' %}
        {% if execute %}
            {% set log_path = 'target/duckdb_query_logs' %}
            {% do run_query("CALL enable_logging('QueryLog', storage_path = '" ~ log_path ~ "');") %}
            {{ log("DuckDB logging enabled with file storage at: " ~ log_path, info=True) }}
        {% endif %}
    {% endif %}
{% endmacro %}
