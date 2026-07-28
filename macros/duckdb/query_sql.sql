{# result_limit is accepted for signature parity across adapters; DuckDB looks the
   query up by id directly, so it has no effect here. #}
{% macro duckdb__get_query_sql(query_id, result_limit=1000) %}
    {# DuckDB requires logging to be enabled with: CALL enable_logging('QueryLog'); #}
    select message as query_text
    from ({{ dbt_query_profiler.duckdb__query_log_lookup(query_id) }})
{% endmacro %}


{% macro duckdb__print_query_sql(query_id, result_limit=1000) %}
    {{ duckdb__ensure_logging_enabled() }}
    {% set query %}
        {{ dbt_query_profiler.get_query_sql(query_id=query_id, result_limit=result_limit) }}
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
