{% macro bigquery__get_query_plan(query_id) %}
    {{ exceptions.raise_compiler_error("get_query_plan is not supported for BigQuery. BigQuery does not expose operator-level execution statistics via SQL.") }}
{% endmacro %}


{% macro bigquery__print_query_plan(query_id, format) %}
    {{ exceptions.raise_compiler_error("print_query_plan is not supported for BigQuery. BigQuery does not expose operator-level execution statistics via SQL.") }}
{% endmacro %}


{% macro bigquery__get_query_plan_summary(query_id) %}
    {{ exceptions.raise_compiler_error("get_query_plan_summary is not supported for BigQuery. BigQuery does not expose operator-level execution statistics via SQL.") }}
{% endmacro %}
