{% macro bigquery__get_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {%- set effective_user = user_name if user_name is not none else target.user -%}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set custom_source = var('bigquery_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select
        job_id as query_id,
        query as query_text,
        user_email as user_name,
        cast(null as string) as warehouse_name,
        statement_type as query_type,
        cast(null as string) as query_tag,
        creation_time as start_time,
        timestamp_diff(end_time, start_time, millisecond) as total_elapsed_time
    {% if custom_source %}
    {# Custom source: user-provided view/table (use_account_level_history is ignored) #}
    from {{ custom_source }}
    {% elif use_account_level %}
    {# Project-level: all jobs in project (requires bigquery.jobs.list permission) #}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
    {% else %}
    {# User-scoped: current user's jobs only (no special permissions required) #}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_USER
    {% endif %}
    where creation_time > timestamp_sub(current_timestamp(), interval 7 day)
        and job_type = 'QUERY'
        and state = 'DONE'
        and not ({{ dbt_query_profiler.contains_text('query', dbt_query_profiler._self_identifier()) }})
    {% if use_account_level and effective_user %}
        and lower(user_email) = lower('{{ dbt_query_profiler._escape_literal(effective_user) }}')
    {% endif %}
    {% if table_name %}
        and {{ dbt_query_profiler.contains_text('lower(query)', table_name | lower) }}
    {% endif %}
    {% if node_id %}
        and {{ dbt_query_profiler.contains_text('query', dbt_query_profiler._node_id_needle(node_id)) }}
    {% endif %}
    {% if query_type %}
        and statement_type = '{{ dbt_query_profiler._escape_literal(query_type | upper) }}'
    {% endif %}
    order by creation_time desc
    limit {{ limit }}
{% endmacro %}


{% macro bigquery__print_query_history(table_name, user_name, query_type, limit, result_limit, node_id=none) %}
    {% set query %}
        /* {{ dbt_query_profiler._self_identifier() }} */
        select to_json_string(array_agg(struct(
            query_id,
            user_name,
            warehouse_name,
            query_type,
            query_tag,
            cast(start_time as string) as start_time,
            total_elapsed_time,
            query_text
        ) order by start_time desc)) as result
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
