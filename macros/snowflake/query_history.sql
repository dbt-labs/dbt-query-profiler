{% macro snowflake__query_lookup_source(result_limit) %}
    {#
        FROM clause for looking up a single query by query_id.

        This must mirror snowflake__get_query_history's source selection, otherwise
        an id handed out by get_query_history is not findable here.

        Both functions take a "most recent N rows" limit, but they count different
        populations: query_history() is account-wide, so on a busy account its
        window fills with other users' queries and reaches back far less in
        wall-clock time than query_history_by_user's does. Using it here means ids
        that get_query_history just returned resolve to "Query not found".

        Raising result_limit is not a substitute - it caps at 10000, which on a busy
        account is still a short window.
    #}
    {%- set custom_source = var('snowflake_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}
    {%- set effective_user = target.user -%}
    {% if custom_source %}
    from {{ custom_source }}
    {% elif use_account_level %}
    from snowflake.account_usage.query_history
    {% elif effective_user %}
    from table(information_schema.query_history_by_user(
        user_name => '{{ dbt_query_profiler._escape_literal(effective_user) }}',
        result_limit => {{ result_limit }}
    ))
    {% else %}
    from table(information_schema.query_history(result_limit => {{ result_limit }}))
    {% endif %}
{% endmacro %}


{% macro snowflake__get_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
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
        and lower(user_name) = lower('{{ dbt_query_profiler._escape_literal(effective_user) }}')
    {% endif %}
    {% else %}
    {# User-scoped: information_schema - 7 days retention, no latency #}
    {% if effective_user %}
    from table(information_schema.query_history_by_user(
        user_name => '{{ dbt_query_profiler._escape_literal(effective_user) }}',
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


{% macro snowflake__print_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
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
        from ({{ dbt_query_profiler.get_query_history(table_name=table_name, user_name=user_name, query_type=query_type, limit=limit, result_limit=result_limit, node_id=node_id) }})
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
