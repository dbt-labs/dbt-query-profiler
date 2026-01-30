{% macro get_query_plan(sql) %}
    {{ return(adapter.dispatch('get_query_plan', 'dbt_query_profiler')(sql=sql)) }}
{% endmacro %}


{% macro default__get_query_plan(sql) %}
    {{ exceptions.raise_compiler_error("get_query_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro print_query_plan(sql, format='text') %}
    {{ return(adapter.dispatch('print_query_plan', 'dbt_query_profiler')(sql=sql, format=format)) }}
{% endmacro %}


{% macro default__print_query_plan(sql, format) %}
    {{ exceptions.raise_compiler_error("print_query_plan is not supported for adapter: " ~ target.type ~ ". Supported adapters: snowflake, databricks, redshift, duckdb") }}
{% endmacro %}


{% macro get_query_plan_model(model_name) %}
    {# Get compiled SQL from dbt graph and run EXPLAIN #}
    {% set model_node = None %}

    {# Search for the model in the graph #}
    {% for node in graph.nodes.values() %}
        {% if node.resource_type == 'model' and node.name == model_name %}
            {% set model_node = node %}
        {% endif %}
    {% endfor %}

    {% if model_node is none %}
        {{ exceptions.raise_compiler_error("Model '" ~ model_name ~ "' not found in graph. Make sure the model exists and is compiled.") }}
    {% endif %}

    {% set compiled_sql = model_node.compiled_code %}

    {% if compiled_sql is none or compiled_sql == '' %}
        {{ exceptions.raise_compiler_error("Model '" ~ model_name ~ "' has no compiled SQL. Run 'dbt compile' first.") }}
    {% endif %}

    {{ return(dbt_query_profiler.get_query_plan(sql=compiled_sql)) }}
{% endmacro %}


{% macro print_query_plan_model(model_name, format='text') %}
    {# Get compiled SQL from dbt graph and print EXPLAIN #}
    {% set model_node = None %}

    {# Search for the model in the graph #}
    {% for node in graph.nodes.values() %}
        {% if node.resource_type == 'model' and node.name == model_name %}
            {% set model_node = node %}
        {% endif %}
    {% endfor %}

    {% if model_node is none %}
        {{ exceptions.raise_compiler_error("Model '" ~ model_name ~ "' not found in graph. Make sure the model exists and is compiled.") }}
    {% endif %}

    {% set compiled_sql = model_node.compiled_code %}

    {% if compiled_sql is none or compiled_sql == '' %}
        {{ exceptions.raise_compiler_error("Model '" ~ model_name ~ "' has no compiled SQL. Run 'dbt compile' first.") }}
    {% endif %}

    {{ return(dbt_query_profiler.print_query_plan(sql=compiled_sql, format=format)) }}
{% endmacro %}
