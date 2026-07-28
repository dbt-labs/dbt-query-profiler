{# result_limit is accepted for signature parity across adapters; BigQuery filters
   by job_id directly, so it has no effect here. #}
{% macro bigquery__get_query_sql(query_id, result_limit=1000) %}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set custom_source = var('bigquery_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select query as query_text
    {% if custom_source %}
    from {{ custom_source }}
    {% elif use_account_level %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
    {% else %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_USER
    {% endif %}
    where job_id = '{{ query_id }}'
{% endmacro %}


{% macro bigquery__print_query_sql(query_id, result_limit=1000) %}
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
