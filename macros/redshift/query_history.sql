{% macro redshift__get_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {%- set custom_source = var('redshift_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'sys_query_history' -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}
    {#
        Redshift has no separate account-level source: sys_query_history is one view
        whose visibility depends on the connected user's privileges. Superusers see
        all rows, and regular users see only their own unless granted
        SYSLOG ACCESS UNRESTRICTED. So account-level here means dropping the username
        filter and letting the warehouse decide - same approach as Databricks.

        Note this grants nothing: without the privilege a regular user still sees only
        their own queries, so the var is safe but silently ineffective for them.
        https://docs.aws.amazon.com/redshift/latest/dg/SYS_QUERY_HISTORY.html
    #}
    {%- set effective_user = user_name if user_name is not none
                             else (none if (use_account_level or custom_source) else target.user) -%}

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
    {# getdate() returns `timestamp`; current_timestamp returns `timestamp with time zone`,
       for which Redshift's DATEADD has no overload - it fails with
       "function pg_catalog.date_add(..., timestamp with time zone) does not exist". #}
    where start_time > dateadd(day, -7, getdate())
        and status = 'success'
        and position('{{ dbt_query_profiler._self_identifier() }}' in query_text) = 0
    {% if effective_user %}
        and lower(username) = lower('{{ dbt_query_profiler._escape_literal(effective_user) }}')
    {% endif %}
    {% if table_name %}
        and position(lower('{{ dbt_query_profiler._escape_literal(table_name) }}') in lower(query_text)) > 0
    {% endif %}
    {% if node_id %}
        and position('{{ dbt_query_profiler._escape_literal(node_id) }}' in query_text) > 0
    {% endif %}
    {% if query_type %}
        and query_type = '{{ dbt_query_profiler._escape_literal(query_type | upper) }}'
    {% endif %}
    order by start_time desc
    limit {{ limit }}
{% endmacro %}


{% macro redshift__print_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {% set query %}
        /* {{ dbt_query_profiler._self_identifier() }} */
        select json_serialize(
            json_parse('[' || listagg(
                json_serialize(
                    object(
                        'query_id', query_id,
                        'user_name', user_name,
                        'warehouse_name', warehouse_name,
                        'query_type', query_type,
                        'query_tag', query_tag,
                        {# OBJECT cannot convert timestamp to SUPER - cast, as the other adapters do #}
                        'start_time', start_time::varchar,
                        'total_elapsed_time', total_elapsed_time,
                        'query_text', query_text
                    )
                ), ','
            ) within group (order by start_time desc) || ']')
        ) as result
        from ({{ dbt_query_profiler.get_query_history(table_name=table_name, user_name=user_name, query_type=query_type, limit=limit, result_limit=result_limit, node_id=node_id) }})
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
