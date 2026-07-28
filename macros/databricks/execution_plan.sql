{% macro databricks__get_execution_plan(query_id) %}
    {%- set custom_source = var('databricks_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'system.query.history' -%}
    {# First, get the query text from history #}
    {% set sql_query %}
        select statement_text
        from {{ source_table }}
        where statement_id = '{{ query_id }}'
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        explain extended {{ original_sql }}
    {% elif not execute %}
        {#
            Parse time: run_query is a no-op and returns none, so there is no statement
            text to build an EXPLAIN from yet. Emit shape-compatible placeholder SQL
            (Databricks EXPLAIN returns a single `plan` column) instead of raising —
            raising here aborts `dbt parse` for the entire project, not just the model
            using this macro. The real EXPLAIN is built on the execute pass.
        #}
        select cast(null as string) as plan limit 0
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with statement_id: " ~ query_id) }}
    {% endif %}
{% endmacro %}


{% macro databricks__print_execution_plan(query_id, format) %}
    {%- set custom_source = var('databricks_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'system.query.history' -%}
    {# First, get the query text from history #}
    {% set sql_query %}
        select statement_text
        from {{ source_table }}
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
    {%- set custom_source = var('databricks_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'system.query.history' -%}
    {# First, get the query text from history #}
    {% set sql_query %}
        select statement_text
        from {{ source_table }}
        where statement_id = '{{ query_id }}'
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        explain cost {{ original_sql }}
    {% elif not execute %}
        {# Parse time placeholder - see databricks__get_execution_plan rationale above. #}
        select cast(null as string) as plan limit 0
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with statement_id: " ~ query_id) }}
    {% endif %}
{% endmacro %}
