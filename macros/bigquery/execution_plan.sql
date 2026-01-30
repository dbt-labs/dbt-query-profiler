{% macro bigquery__get_execution_plan(query_id) %}
    {{ exceptions.raise_compiler_error("get_execution_plan is not supported for BigQuery. BigQuery does not expose operator-level execution statistics via SQL.") }}
{% endmacro %}


{% macro bigquery__print_execution_plan(query_id, format) %}
    {{ exceptions.raise_compiler_error("print_execution_plan is not supported for BigQuery. BigQuery does not expose operator-level execution statistics via SQL.") }}
{% endmacro %}


{% macro bigquery__get_execution_plan_summary(query_id) %}
    {{ exceptions.raise_compiler_error("get_execution_plan_summary is not supported for BigQuery. BigQuery does not expose operator-level execution statistics via SQL.") }}
{% endmacro %}
