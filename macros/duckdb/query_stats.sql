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
        {# EXPLAIN ANALYZE with JSON format to get structured stats #}
        explain analyze (format json) {{ original_sql }}
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__print_query_stats(query_id, format, result_limit) %}
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

        {% if format == 'text' %}
            {# Run EXPLAIN ANALYZE and extract key metrics #}
            {% set explain_query %}
                explain analyze {{ original_sql }}
            {% endset %}

            {% set results = run_query(explain_query) %}

            {% if results and results.rows %}
                {{ print("Query ID:     " ~ query_id) }}
                {{ print("Note:         Stats from re-execution via EXPLAIN ANALYZE") }}
                {{ print("") }}
                {% for row in results.rows %}
                    {{ print(row[0]) }}
                {% endfor %}
            {% else %}
                {{ print("No stats found") }}
            {% endif %}
        {% else %}
            {# JSON format #}
            {% set explain_query %}
                explain analyze (format json) {{ original_sql }}
            {% endset %}

            {% set results = run_query(explain_query) %}

            {% if results and results.rows and results.rows[0][0] %}
                {{ print(results.rows[0][0]) }}
            {% else %}
                {{ print("No stats found") }}
            {% endif %}
        {% endif %}
    {% else %}
        {{ print("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}
