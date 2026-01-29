{% macro snowflake__get_query_plan(query_id) %}
    select
        operator_id,
        parent_operators,
        operator_type,
        operator_statistics,
        execution_time_breakdown,
        operator_attributes
    from table(get_query_operator_stats('{{ query_id }}'))
    order by operator_id
{% endmacro %}


{% macro snowflake__print_query_plan(query_id, format) %}

    {% if format == 'text' %}
        {% set query %}
            select
                operator_id,
                operator_type,
                nvl(operator_statistics:"input_rows"::varchar, '-') as input_rows,
                nvl(operator_statistics:"output_rows"::varchar, '-') as output_rows,
                nvl(round(execution_time_breakdown:"overall_percentage"::float * 100, 1)::varchar, '-') as pct
            from table(get_query_operator_stats('{{ query_id }}'))
            order by operator_id
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% for row in results.rows %}
                {{ print("[" ~ row[0] ~ "] " ~ row[1] ~ "  (in: " ~ row[2] ~ ", out: " ~ row[3] ~ ", time: " ~ row[4] ~ "%)") }}
            {% endfor %}
        {% else %}
            {{ print("No query plan found") }}
        {% endif %}

    {% elif format == 'markdown' %}
        {% set query %}
            select
                operator_id,
                operator_type,
                operator_statistics:"input_rows"::number as input_rows,
                operator_statistics:"output_rows"::number as output_rows,
                execution_time_breakdown:"overall_percentage"::float as pct
            from table(get_query_operator_stats('{{ query_id }}'))
            order by operator_id
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {{ print("| ID | Operator | Input Rows | Output Rows | Time % |") }}
            {{ print("|---:|:---------|----------:|----------:|------:|") }}
            {% for row in results.rows %}
                {%- set input_rows = row[2] if row[2] is not none else '-' -%}
                {%- set output_rows = row[3] if row[3] is not none else '-' -%}
                {%- set pct = (row[4] * 100) | round(1) if row[4] is not none else '-' -%}
                {{ print("| " ~ row[0] ~ " | " ~ row[1] ~ " | " ~ input_rows ~ " | " ~ output_rows ~ " | " ~ pct ~ " |") }}
            {% endfor %}
        {% else %}
            {{ print("No query plan found") }}
        {% endif %}

    {% else %}
        {# JSON format (default) #}
        {% set query %}
            select
                array_agg(
                    object_construct(
                        'operator_id', operator_id,
                        'parent_operators', parent_operators,
                        'operator_type', operator_type,
                        'operator_statistics', parse_json(operator_statistics),
                        'execution_time_breakdown', parse_json(execution_time_breakdown),
                        'operator_attributes', parse_json(operator_attributes)
                    )
                ) within group (order by operator_id) as plan_json
            from table(get_query_operator_stats('{{ query_id }}'))
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("No query plan found") }}
        {% endif %}
    {% endif %}

{% endmacro %}


{% macro snowflake__get_query_plan_summary(query_id) %}
    select
        operator_id,
        operator_type,
        operator_statistics:"input_rows"::number as input_rows,
        operator_statistics:"output_rows"::number as output_rows,
        operator_statistics:"spilling"::object as spilling_info,
        execution_time_breakdown:"overall_percentage"::float as overall_percentage
    from table(get_query_operator_stats('{{ query_id }}'))
    order by operator_id
{% endmacro %}
