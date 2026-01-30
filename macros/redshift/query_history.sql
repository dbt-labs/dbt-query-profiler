{% macro redshift__get_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {%- set effective_user = user_name if user_name is not none else target.user -%}
    {%- set custom_source = var('redshift_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'sys_query_history' -%}

    select
        query_id,
        query_text,
        username as user_name,
        database_name as warehouse_name,
        query_type,
        query_label as query_tag,
        start_time,
        elapsed_time / 1000 as total_elapsed_time  {# Convert microseconds to milliseconds #}
    from {{ source_table }}
    where start_time > dateadd(day, -7, current_timestamp)
        and status = 'success'
        and query_text not like '%{{ dbt_query_profiler._self_identifier() }}%'
    {% if effective_user %}
        and lower(username) = lower('{{ effective_user }}')
    {% endif %}
    {% if table_name %}
        and lower(query_text) like '%{{ table_name | lower }}%'
    {% endif %}
    {% if query_type %}
        and query_type = '{{ query_type | upper }}'
    {% endif %}
    order by start_time desc
    limit {{ limit }}
{% endmacro %}


{% macro redshift__print_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {% set query %}
        /* {{ dbt_query_profiler._self_identifier() }} */
        select json_serialize(
            json_parse('[' || listagg(
                json_serialize(
                    json_build_object(
                        'query_id', query_id,
                        'user_name', user_name,
                        'warehouse_name', warehouse_name,
                        'query_type', query_type,
                        'query_tag', query_tag,
                        'start_time', start_time,
                        'total_elapsed_time', total_elapsed_time,
                        'query_text', query_text
                    )
                ), ','
            ) within group (order by start_time desc) || ']')
        ) as result
        from ({{ dbt_query_profiler.get_query_history(table_name=table_name, user_name=user_name, query_type=query_type, limit=limit, result_limit=result_limit) }})
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute and results and results.rows and results.rows[0][0] %}
        {{ print(results.rows[0][0]) }}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ print("No query found") }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
