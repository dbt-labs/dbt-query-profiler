{# result_limit is accepted for signature parity across adapters; Redshift filters
   by query_id directly, so it has no effect here. #}
{% macro redshift__get_query_sql(query_id, result_limit=1000) %}
    {%- set custom_source = var('redshift_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'sys_query_history' -%}
    select query_text
    from {{ source_table }}
    where query_id = {{ query_id }}
{% endmacro %}


{% macro redshift__print_query_sql(query_id, result_limit=1000) %}
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
