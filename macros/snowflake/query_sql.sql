{% macro snowflake__get_query_sql(query_id, result_limit=1000) %}
    select query_text
    {{ dbt_query_profiler.snowflake__query_lookup_source(result_limit) }}
    where query_id = '{{ query_id }}'
{% endmacro %}


{% macro snowflake__print_query_sql(query_id, result_limit=1000) %}
    {% set query %}
        {{ dbt_query_profiler.get_query_sql(query_id=query_id, result_limit=result_limit) }}
    {% endset %}

    {% set results = run_query(query) %}
    {% if execute and results and results.rows %}
        {{ print(results.rows[0][0]) }}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ print("Query not found") }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
