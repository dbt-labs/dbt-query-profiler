{% macro duckdb__get_query_sql(query_id) %}
    {# DuckDB requires logging to be enabled with: CALL enable_logging('QueryLog'); #}
    select message as query_text
    from duckdb_logs
    where type = 'QueryLog'
        and query_id = {{ query_id }}
{% endmacro %}


{% macro duckdb__print_query_sql(query_id) %}
    {{ duckdb__ensure_logging_enabled() }}
    {% set query %}
        {{ dbt_query_profiler.get_query_sql(query_id=query_id) }}
    {% endset %}

    {% set results = run_query(query) %}
    {% if execute and results and results.rows %}
        {{ print(results.rows[0][0]) }}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ print("Query not found. Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
