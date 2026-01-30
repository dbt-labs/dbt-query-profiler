{% macro duckdb__extract_select_from_ddl(query_text) %}
    {#
        Extract the SELECT portion from a CREATE TABLE/VIEW AS statement.

        WHY THIS IS NEEDED:
        DuckDB's query logs capture the full SQL executed, including DDL statements.
        When dbt materializes a model as a table, the logged query is:
            CREATE TABLE "schema"."model" AS (SELECT ...)

        EXPLAIN ANALYZE only works on SELECT statements, not DDL. So we need to
        extract just the SELECT portion to analyze query performance.

        WHAT THIS DOES:
        - For DDL like "create table x as (select ...)" → returns just "select ..."
        - For pure SELECT statements → returns as-is
        - Handles queries that start with dbt comments like /* {...} */

        Uses dbt's modules.re for regex with inline flags:
        - (?i) case-insensitive matching
        - (?s) DOTALL mode (. matches newlines)
    #}

    {# Use regex to check if this is a CREATE ... AS ( pattern #}
    {% set match = modules.re.search('(?is)create\\s+.*?\\s+as\\s*\\(', query_text) %}

    {% if match %}
        {# Extract the SELECT statement - find 'select' and take everything from there #}
        {% set select_match = modules.re.search('(?is)(select\\s+.*)\\s*\\);?\\s*$', query_text) %}
        {% if select_match %}
            {{ return(select_match.group(1)) }}
        {% endif %}
        {# Fallback: extract everything after ' as (' #}
        {% set inner_sql = modules.re.sub('(?is)^.*?\\s+as\\s*\\(\\s*', '', query_text) %}
        {% set inner_sql = modules.re.sub('\\s*\\);?\\s*$', '', inner_sql) %}
        {{ return(inner_sql) }}
    {% endif %}

    {# Not a DDL statement, return as-is #}
    {{ return(query_text) }}
{% endmacro %}


{% macro duckdb__get_query_stats(query_id, result_limit) %}
    {# First, get the query text from logs #}
    {% set sql_query %}
        select message
        from duckdb_logs
        where type = 'QueryLog'
            and query_id = {{ query_id }}
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        {%- set select_sql = duckdb__extract_select_from_ddl(original_sql) -%}
        {# EXPLAIN ANALYZE with JSON format to get structured stats #}
        explain (analyze, format json) {{ select_sql }}
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__print_query_stats(query_id, format, result_limit) %}
    {{ duckdb__ensure_logging_enabled() }}
    {# First, get the query text from logs #}
    {% set sql_query %}
        select message
        from duckdb_logs
        where type = 'QueryLog'
            and query_id = {{ query_id }}
    {% endset %}

    {% set sql_result = run_query(sql_query) %}

    {% if execute and sql_result and sql_result.rows and sql_result.rows[0][0] %}
        {%- set original_sql = sql_result.rows[0][0] -%}
        {%- set select_sql = duckdb__extract_select_from_ddl(original_sql) -%}

        {% if format == 'text' %}
            {# Run EXPLAIN ANALYZE and extract key metrics #}
            {# Include self-identifier so this query is excluded from future history searches #}
            {% set explain_query %}
                /* {{ dbt_query_profiler._self_identifier() }} */
                explain analyze {{ select_sql }}
            {% endset %}

            {% set results = run_query(explain_query) %}

            {% if results and results.rows %}
                {{ print("Query ID:     " ~ query_id) }}
                {{ print("Note:         Stats from re-execution via EXPLAIN ANALYZE") }}
                {{ print("") }}
                {# DuckDB returns (column_name, plan_text) - print the plan (second column) #}
                {% for row in results.rows %}
                    {% if row | length > 1 %}
                        {{ print(row[1]) }}
                    {% else %}
                        {{ print(row[0]) }}
                    {% endif %}
                {% endfor %}
            {% else %}
                {{ print("No stats found") }}
            {% endif %}
        {% else %}
            {# JSON format #}
            {# Include self-identifier so this query is excluded from future history searches #}
            {% set explain_query %}
                /* {{ dbt_query_profiler._self_identifier() }} */
                explain (analyze, format json) {{ select_sql }}
            {% endset %}

            {% set results = run_query(explain_query) %}

            {# DuckDB returns (column_name, json_content) - print the JSON (second column) #}
            {% if results and results.rows and results.rows[0] | length > 1 %}
                {{ print(results.rows[0][1]) }}
            {% elif results and results.rows and results.rows[0][0] %}
                {{ print(results.rows[0][0]) }}
            {% else %}
                {{ print("No stats found") }}
            {% endif %}
        {% endif %}
    {% else %}
        {{ print("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}
