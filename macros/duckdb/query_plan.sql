{% macro duckdb__get_query_plan(sql) %}
    explain {{ sql }}
{% endmacro %}


{% macro duckdb__print_query_plan(sql, format) %}
    {% set explain_query %}
        explain (format {{ format if format in ['json', 'text', 'graphviz', 'html'] else 'text' }}) {{ sql }}
    {% endset %}

    {% set results = run_query(explain_query) %}

    {% if execute and results and results.rows %}
        {% for row in results.rows %}
            {{ print(row[0]) }}
        {% endfor %}
    {% else %}
        {{ print("No query plan generated") }}
    {% endif %}
{% endmacro %}
