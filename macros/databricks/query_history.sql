{% macro databricks__get_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {%- set custom_source = var('databricks_query_history_source', none) -%}
    {%- set source_table = custom_source if custom_source else 'system.query.history' -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}
    {# For user-scoped, always filter by current user unless explicitly requesting all users #}
    {# When using a custom source, use_account_level_history is ignored - the view controls access #}
    {%- set effective_user = user_name if user_name is not none else (none if (use_account_level or custom_source) else 'current_user()') -%}

    select
        statement_id as query_id,
        statement_text as query_text,
        executed_by as user_name,
        compute.warehouse_id as warehouse_name,
        statement_type as query_type,
        cast(null as string) as query_tag,
        start_time,
        total_duration_ms as total_elapsed_time
    from {{ source_table }}
    where start_time > dateadd(day, -7, current_timestamp())
        and execution_status = 'FINISHED'
        and statement_text not like '%{{ dbt_query_profiler._self_identifier() }}%'
    {% if effective_user == 'current_user()' %}
        and executed_by = current_user()
    {% elif effective_user %}
        and lower(executed_by) = lower('{{ effective_user }}')
    {% endif %}
    {% if table_name %}
        and lower(statement_text) like '%{{ table_name | lower }}%'
    {% endif %}
    {% if query_type %}
        and statement_type = '{{ query_type | upper }}'
    {% endif %}
    order by start_time desc
    limit {{ limit }}
{% endmacro %}


{% macro databricks__print_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {% set query %}
        /* {{ dbt_query_profiler._self_identifier() }} */
        select to_json(collect_list(struct(
            query_id,
            user_name,
            warehouse_name,
            query_type,
            query_tag,
            cast(start_time as string) as start_time,
            total_elapsed_time,
            query_text
        ))) as result
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
