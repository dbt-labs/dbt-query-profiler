{% macro snowflake__get_query_plan(sql) %}
    explain using tabular {{ sql }}
{% endmacro %}


{% macro snowflake__print_query_plan(sql, format) %}
    {% set explain_query %}
        explain using {{ 'json' if format == 'json' else 'tabular' }} {{ sql }}
    {% endset %}

    {% set results = run_query(explain_query) %}

    {% if execute and results and results.rows %}
        {% if format == 'json' %}
            {# JSON format returns a single row with JSON #}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {# Tabular format - print each row #}
            {% for row in results.rows %}
                {{ print(row | join(' | ')) }}
            {% endfor %}
        {% endif %}
    {% else %}
        {{ print("No query plan generated") }}
    {% endif %}
{% endmacro %}
