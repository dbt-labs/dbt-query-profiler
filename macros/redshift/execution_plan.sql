{% macro redshift__explain_join(query_id) %}
    {#
        FROM/JOIN/WHERE for reaching stl_explain from a get_query_history query_id.

        sys_query_history.query_id and stl_explain.query are different ID spaces, so
        `stl_explain where query = <query_id>` never matches. AWS documents
        correlating them via transaction_id plus time bounds:
        https://repost.aws/knowledge-center/redshift-query-id-match-tables

        A transaction can contain more than one explained statement, so this can
        return several plans. statement_id is therefore selected and ordered on
        first: callers can tell the plans apart rather than reading a merged,
        incoherent tree. Do not collapse this to a single plan with a LIMIT - that
        would silently return an arbitrary statement's plan.
    #}
    from sys_query_history h
    join stl_query q
        on q.xid = h.transaction_id
       and q.starttime between h.start_time and h.end_time
       and q.endtime between h.start_time and h.end_time
    join stl_explain e
        on e.query = q.query
    where h.query_id = {{ query_id }}
{% endmacro %}


{% macro redshift__no_plan_message() %}No execution plan found. STL tables are pruned aggressively, so plans are usually unavailable for older queries.{% endmacro %}


{% macro redshift__get_execution_plan(query_id) %}
    select
        q.query as statement_id,
        e.nodeid as operator_id,
        e.parentid as parent_operator_id,
        rtrim(e.plannode) as operator_type,
        trim(e.info) as operator_info
    {{ dbt_query_profiler.redshift__explain_join(query_id) }}
    order by q.query, e.nodeid
{% endmacro %}


{% macro redshift__print_execution_plan(query_id, format) %}

    {% if format == 'text' %}
        {% set query %}
            select
                q.query as statement_id,
                e.nodeid,
                rtrim(e.plannode) as plannode,
                trim(e.info) as info
            {{ dbt_query_profiler.redshift__explain_join(query_id) }}
            order by q.query, e.nodeid
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {%- set multiple = (results.rows | map(attribute=0) | unique | list | length) > 1 -%}
            {% if multiple %}
                {{ print("Note: this transaction contained more than one explained statement; plans are grouped by statement_id.") }}
            {% endif %}
            {%- set ns = namespace(current=none) -%}
            {% for row in results.rows %}
                {% if multiple and row[0] != ns.current %}
                    {%- set ns.current = row[0] -%}
                    {{ print("") }}
                    {{ print("statement_id " ~ row[0] ~ ":") }}
                {% endif %}
                {{ print("[" ~ row[1] ~ "] " ~ row[2] ~ " " ~ (row[3] if row[3] else '')) }}
            {% endfor %}
        {% else %}
            {{ print(dbt_query_profiler.redshift__no_plan_message()) }}
        {% endif %}

    {% else %}
        {# JSON format (default) #}
        {% set query %}
            select json_serialize(
                json_parse('[' || listagg(
                    json_serialize(
                        object(
                            'statement_id', statement_id,
                            'operator_id', operator_id,
                            'parent_operator_id', parent_operator_id,
                            'operator_type', operator_type,
                            'operator_info', operator_info
                        )
                    ), ','
                ) within group (order by statement_id, operator_id) || ']')
            ) as plan_json
            from ({{ dbt_query_profiler.redshift__get_execution_plan(query_id) }})
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print(dbt_query_profiler.redshift__no_plan_message()) }}
        {% endif %}
    {% endif %}

{% endmacro %}


{% macro redshift__get_execution_plan_summary(query_id) %}
    {# Redshift has no separate summary concept - stl_explain is already node-level. #}
    {{ return(dbt_query_profiler.redshift__get_execution_plan(query_id=query_id)) }}
{% endmacro %}
