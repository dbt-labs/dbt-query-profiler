{% macro bigquery__get_query_sql(query_id) %}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select query as query_text
    {% if use_account_level %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
    {% else %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_USER
    {% endif %}
    where job_id = '{{ query_id }}'
{% endmacro %}


{% macro bigquery__print_query_sql(query_id) %}
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
