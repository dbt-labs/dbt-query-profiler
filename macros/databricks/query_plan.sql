{% macro databricks__get_query_plan(sql) %}
    explain extended {{ sql }}
{% endmacro %}


{% macro databricks__print_query_plan(sql, format) %}
    {% set explain_query %}
        explain {{ 'extended' if format == 'json' else 'formatted' }} {{ sql }}
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
