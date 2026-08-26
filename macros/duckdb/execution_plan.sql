{% macro duckdb__get_execution_plan(query_id) %}
    {# First, get the query text from logs (see duckdb__query_log_lookup). #}
    {% set sql_query %}
        {{ dbt_query_profiler.duckdb__query_log_lookup(query_id) }}
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        explain {{ original_sql }}
    {% elif not execute %}
        {#
            Parse time: run_query is a no-op and returns none, so there is no query
            text to build an EXPLAIN from yet. Emit shape-compatible placeholder SQL
            (DuckDB EXPLAIN returns explain_key, explain_value) instead of raising —
            raising here aborts `dbt parse` for the entire project, not just the model
            using this macro. The real EXPLAIN is built on the execute pass.
        #}
        select cast(null as varchar) as explain_key, cast(null as varchar) as explain_value limit 0
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with query_id: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__print_execution_plan(query_id, format, min_pct=none, top_n=none) %}
    {# min_pct/top_n are Snowflake-only filters (see snowflake__print_execution_plan) - accepted and ignored here so the shared dispatch call works on every adapter. #}
    {{ duckdb__ensure_logging_enabled() }}
    {# First, get the query text from logs #}
    {% set sql_query %}
        {{ dbt_query_profiler.duckdb__query_log_lookup(query_id) }}
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}

        {# Run EXPLAIN with appropriate format (no ANALYZE - use query_stats for that) #}
        {# Include self-identifier so this EXPLAIN is excluded from future history
           searches - otherwise the profiler re-profiles its own EXPLAIN and DuckDB
           rejects the nested statement. #}
        {% set explain_query %}
            /* {{ dbt_query_profiler._self_identifier() }} */
            explain (format {{ format if format in ['json', 'text', 'graphviz', 'html'] else 'text' }}) {{ original_sql }}
        {% endset %}

        {% set results = run_query(explain_query) %}

        {% if results and results.rows %}
            {# DuckDB EXPLAIN returns (explain_key, explain_value) - print the plan (second column) #}
            {% for row in results.rows %}
                {% if row | length > 1 %}
                    {{ print(row[1]) }}
                {% else %}
                    {{ print(row[0]) }}
                {% endif %}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}
    {% else %}
        {{ print("Query not found with query_id: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__get_execution_plan_summary(query_id) %}
    {# First, get the query text from logs #}
    {% set sql_query %}
        {{ dbt_query_profiler.duckdb__query_log_lookup(query_id) }}
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        explain {{ original_sql }}
    {% elif not execute %}
        {#
            Parse time: run_query is a no-op and returns none, so there is no query
            text to build an EXPLAIN from yet. Emit shape-compatible placeholder SQL
            (DuckDB EXPLAIN returns explain_key, explain_value) instead of raising —
            raising here aborts `dbt parse` for the entire project, not just the model
            using this macro. The real EXPLAIN is built on the execute pass.
        #}
        select cast(null as varchar) as explain_key, cast(null as varchar) as explain_value limit 0
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with query_id: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__print_execution_plan_summary(query_id, format) %}
    {# get_execution_plan_summary above is identical to get_execution_plan (plain EXPLAIN, no ANALYZE) - nothing distinct to print. #}
    {{ return(dbt_query_profiler.duckdb__print_execution_plan(query_id=query_id, format=format)) }}
{% endmacro %}
