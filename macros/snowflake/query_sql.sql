{% macro snowflake__get_query_sql(query_id) %}
    {%- set custom_source = var('snowflake_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select query_text
    {% if custom_source %}
    from {{ custom_source }}
    {% elif use_account_level %}
    from snowflake.account_usage.query_history
    {% else %}
    from table(information_schema.query_history())
    {% endif %}
    where query_id = '{{ query_id }}'
{% endmacro %}


{% macro snowflake__print_query_sql(query_id) %}
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
