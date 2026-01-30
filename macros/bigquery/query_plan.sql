{% macro bigquery__get_query_plan(sql) %}
    {{ exceptions.raise_compiler_error("get_query_plan is not supported for BigQuery. BigQuery does not have an EXPLAIN command. Use the BigQuery console or API for query plans.") }}
{% endmacro %}


{% macro bigquery__print_query_plan(sql, format) %}
    {{ exceptions.raise_compiler_error("print_query_plan is not supported for BigQuery. BigQuery does not have an EXPLAIN command. Use the BigQuery console or API for query plans.") }}
{% endmacro %}
