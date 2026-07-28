{# result_limit is accepted for signature parity across adapters; Databricks filters
   by statement_id directly, so it has no effect here. #}
{% macro databricks__get_query_sql(query_id, result_limit=1000) %}
    {%- set custom_source = var('databricks_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'system.query.history' -%}
    select statement_text as query_text
    from {{ source_table }}
    where statement_id = '{{ query_id }}'
{% endmacro %}


{% macro databricks__print_query_sql(query_id, result_limit=1000) %}
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
