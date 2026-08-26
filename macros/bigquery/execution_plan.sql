{% macro bigquery__get_execution_plan(query_id) %}
    {#
        BigQuery does not expose operator-level execution plans via SQL.
        Instead, this returns Query Insights (performance_insights) from INFORMATION_SCHEMA,
        which provides diagnostics like slot contention, high cardinality joins, and partition skew.
        See: https://cloud.google.com/bigquery/docs/query-insights
    #}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set custom_source = var('bigquery_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}

    select to_json_string(query_info.performance_insights) as insights
    {% if custom_source %}
    from {{ custom_source }}
    {% elif use_account_level %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
    {% else %}
    from `region-{{ region }}`.INFORMATION_SCHEMA.JOBS_BY_USER
    {% endif %}
    where job_id = '{{ query_id }}'
{% endmacro %}


{% macro bigquery__print_execution_plan(query_id, format, min_pct=none, top_n=none) %}
    {# min_pct/top_n are Snowflake-only filters (see snowflake__print_execution_plan) - accepted and ignored here so the shared dispatch call works on every adapter. #}
    {%- set region = target.location if target.location else 'us' -%}
    {%- set custom_source = var('bigquery_query_history_source', none) -%}
    {%- set use_account_level = var('use_account_level_history', false) -%}
    {%- set source_table = custom_source if custom_source else ('`region-' ~ region ~ '`.INFORMATION_SCHEMA.' ~ ('JOBS_BY_PROJECT' if use_account_level else 'JOBS_BY_USER')) -%}

    {% set query %}
        select to_json_string(query_info.performance_insights) as insights
        from {{ source_table }}
        where job_id = '{{ query_id }}'
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute and results and results.rows and results.rows[0][0] %}
        {% set insights = results.rows[0][0] %}
        {% if format == 'text' %}
            {{ print("Note: BigQuery does not expose operator-level execution plans.") }}
            {{ print("      Showing Query Insights (performance diagnostics) instead.") }}
            {{ print("      See: https://cloud.google.com/bigquery/docs/query-insights") }}
            {{ print("") }}
            {{ print(insights) }}
        {% else %}
            {{ print(insights) }}
        {% endif %}
    {% elif execute and results and results.rows %}
        {{ print("No performance insights found for this query. The query may have run without detectable issues, or insights are not available for this job.") }}
    {% else %}
        {{ print("Query not found") }}
    {% endif %}
{% endmacro %}


{% macro bigquery__get_execution_plan_summary(query_id) %}
    {# Returns the same Query Insights as get_execution_plan — BigQuery has no separate summary concept. #}
    {{ return(dbt_query_profiler.bigquery__get_execution_plan(query_id=query_id)) }}
{% endmacro %}


{% macro bigquery__print_execution_plan_summary(query_id, format) %}
    {# Same reasoning as get_execution_plan_summary above - no distinct summary to print. #}
    {{ return(dbt_query_profiler.bigquery__print_execution_plan(query_id=query_id, format=format)) }}
{% endmacro %}
