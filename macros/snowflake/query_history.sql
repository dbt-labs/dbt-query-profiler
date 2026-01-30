{% macro snowflake__get_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {%- set effective_user = user_name if user_name is not none else target.user -%}
    {%- set custom_source = var('snowflake_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select
        query_id,
        query_text,
        user_name,
        warehouse_name,
        query_type,
        query_tag,
        start_time,
        total_elapsed_time
    {% if custom_source %}
    {# Custom source: user-provided view/table (use_account_level_history is ignored) #}
    from {{ custom_source }}
    where nvl(query_tag, '') != '{{ dbt_query_profiler._self_identifier() }}'
    {% elif use_account_level %}
    {# Account-level: snowflake.account_usage - 365 days retention, up to 45 min latency #}
    from snowflake.account_usage.query_history
    where start_time > dateadd(day, -365, current_timestamp())
        and nvl(query_tag, '') != '{{ dbt_query_profiler._self_identifier() }}'
    {% if effective_user %}
        and lower(user_name) = lower('{{ effective_user }}')
    {% endif %}
    {% else %}
    {# User-scoped: information_schema - 7 days retention, no latency #}
    {% if effective_user %}
    from table(information_schema.query_history_by_user(
        user_name => '{{ effective_user }}',
        result_limit => {{ result_limit }}
    ))
    {% else %}
    from table(information_schema.query_history(
        result_limit => {{ result_limit }}
    ))
    {% endif %}
    where nvl(query_tag, '') != '{{ dbt_query_profiler._self_identifier() }}'
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


{% macro snowflake__print_query_history(table_name, user_name, query_type, limit, result_limit) %}
    {# Set query tag to exclude this query from results #}
    {% do run_query("ALTER SESSION SET QUERY_TAG = '" ~ dbt_query_profiler._self_identifier() ~ "'") %}

    {% set query %}
        select array_agg(
            object_construct(
                'query_id', query_id,
                'user_name', user_name,
                'warehouse_name', warehouse_name,
                'query_type', query_type,
                'query_tag', query_tag,
                'start_time', start_time,
                'total_elapsed_time', total_elapsed_time,
                'query_text', query_text
            )
        ) within group (order by start_time desc) as result
        from ({{ dbt_query_profiler.get_query_history(table_name=table_name, user_name=user_name, query_type=query_type, limit=limit, result_limit=result_limit) }})
    {% endset %}

    {% set results = run_query(query) %}

    {# Unset query tag #}
    {% do run_query("ALTER SESSION UNSET QUERY_TAG") %}

    {% if execute and results and results.rows and results.rows[0][0] %}
        {{ print(results.rows[0][0]) }}
        {{ return(results.rows[0][0]) }}
    {% else %}
        {{ print("No query found") }}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
