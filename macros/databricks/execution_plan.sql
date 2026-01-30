{% macro databricks__get_execution_plan(query_id) %}
    {# First, get the query text from history #}
    {% set sql_query %}
        select statement_text
        from system.query.history
        where statement_id = '{{ query_id }}'
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        explain extended {{ original_sql }}
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with statement_id: " ~ query_id) }}
    {% endif %}
{% endmacro %}


{% macro databricks__print_execution_plan(query_id, format) %}
    {# First, get the query text from history #}
    {% set sql_query %}
        select statement_text
        from system.query.history
        where statement_id = '{{ query_id }}'
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}

        {# Run EXPLAIN on the original query #}
        {% set explain_query %}
            explain {{ 'extended' if format == 'json' else 'formatted' }} {{ original_sql }}
        {% endset %}

        {% set results = run_query(explain_query) %}

        {% if results and results.rows %}
            {% for row in results.rows %}
                {{ print(row[0]) }}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}
    {% else %}
        {{ print("Query not found with statement_id: " ~ query_id) }}
    {% endif %}
{% endmacro %}


{% macro databricks__get_execution_plan_summary(query_id) %}
    {# First, get the query text from history #}
    {% set sql_query %}
        select statement_text
        from system.query.history
        where statement_id = '{{ query_id }}'
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        explain cost {{ original_sql }}
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with statement_id: " ~ query_id) }}
    {% endif %}
{% endmacro %}
