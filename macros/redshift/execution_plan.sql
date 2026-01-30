{% macro redshift__get_execution_plan(query_id) %}
    select
        nodeid as operator_id,
        parentid as parent_operator_id,
        plannode as operator_type,
        info as operator_info
    from stl_explain
    where query = {{ query_id }}
    order by nodeid
{% endmacro %}


{% macro redshift__print_execution_plan(query_id, format) %}

    {% if format == 'text' %}
        {% set query %}
            select
                nodeid,
                plannode,
                info
            from stl_explain
            where query = {{ query_id }}
            order by nodeid
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% for row in results.rows %}
                {{ print("[" ~ row[0] ~ "] " ~ row[1] ~ " " ~ (row[2] if row[2] else '')) }}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}

    {% else %}
        {# JSON format (default) #}
        {% set query %}
            select json_serialize(
                json_parse('[' || listagg(
                    json_serialize(
                        json_build_object(
                            'operator_id', nodeid,
                            'parent_operator_id', parentid,
                            'operator_type', plannode,
                            'operator_info', info
                        )
                    ), ','
                ) within group (order by nodeid) || ']')
            ) as plan_json
            from stl_explain
            where query = {{ query_id }}
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}
    {% endif %}

{% endmacro %}


{% macro redshift__get_execution_plan_summary(query_id) %}
    select
        nodeid as operator_id,
        parentid as parent_operator_id,
        plannode as operator_type,
        info as operator_info
    from stl_explain
    where query = {{ query_id }}
    order by nodeid
{% endmacro %}
