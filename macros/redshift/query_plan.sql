{% macro redshift__get_query_plan(sql) %}
    explain {{ sql }}
{% endmacro %}


{% macro redshift__print_query_plan(sql, format) %}
    {% set explain_query %}
        explain {{ sql }}
    {% endset %}

    {% set results = run_query(explain_query) %}

    {% if execute and results and results.rows %}
        {% if format == 'json' %}
            {# Build JSON from explain output #}
            {% set lines = [] %}
            {% for row in results.rows %}
                {% do lines.append(row[0]) %}
            {% endfor %}
            {{ print('{"plan": ' ~ (lines | tojson) ~ '}') }}
        {% else %}
            {% for row in results.rows %}
                {{ print(row[0]) }}
            {% endfor %}
        {% endif %}
    {% else %}
        {{ print("No query plan generated") }}
    {% endif %}
{% endmacro %}
