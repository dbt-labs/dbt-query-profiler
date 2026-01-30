{% macro duckdb__get_execution_plan(query_id) %}
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
        explain {{ original_sql }}
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__print_execution_plan(query_id, format) %}
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

        {# Run EXPLAIN with appropriate format (no ANALYZE - use query_stats for that) #}
        {% set explain_query %}
            explain (format {{ format if format in ['json', 'text', 'graphviz', 'html'] else 'text' }}) {{ original_sql }}
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
        {{ print("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}


{% macro duckdb__get_execution_plan_summary(query_id) %}
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
        explain {{ original_sql }}
    {% else %}
        {{ exceptions.raise_compiler_error("Query not found with rowid: " ~ query_id ~ ". Ensure logging is enabled with: CALL enable_logging('QueryLog');") }}
    {% endif %}
{% endmacro %}
