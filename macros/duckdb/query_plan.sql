{% macro duckdb__get_query_plan(sql) %}
    explain {{ sql }}
{% endmacro %}


{% macro duckdb__print_query_plan(sql, format) %}
    {# Include self-identifier so this EXPLAIN is excluded from future history searches #}
    {% set explain_query %}
        /* {{ dbt_query_profiler._self_identifier() }} */
        explain (format {{ format if format in ['json', 'text', 'graphviz', 'html'] else 'text' }}) {{ sql }}
    {% endset %}

    {% set results = run_query(explain_query) %}

    {% if execute and results and results.rows %}
        {# DuckDB EXPLAIN returns (explain_key, explain_value) - print the plan (second column) #}
        {% for row in results.rows %}
            {% if row | length > 1 %}
                {{ print(row[1]) }}
            {% else %}
                {{ print(row[0]) }}
            {% endif %}
        {% endfor %}
    {% else %}
        {{ print("No query plan generated") }}
    {% endif %}
{% endmacro %}
