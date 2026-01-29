{% macro redshift__get_query_sql(query_id) %}
    select query_text
    from sys_query_history
    where query_id = {{ query_id }}
{% endmacro %}


{% macro redshift__print_query_sql(query_id) %}
    {% set query %}
        {{ dbt_query_profiler.get_query_sql(query_id=query_id) }}
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
