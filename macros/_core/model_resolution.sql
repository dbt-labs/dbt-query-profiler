{#
    Resolve a dbt model name to its node id (unique_id).

    dbt's default query_comment embeds node_id in every statement's SQL, which makes it
    an exact key for "this model's statements". Building the id by hand as
    "model.<project>.<model>" breaks for models that live in installed packages, so the
    graph is the source of truth where it is available.
#}
{% macro resolve_node_id(model_name) %}
    {%- if graph is not defined or not graph or not graph.get('nodes') -%}
        {#- graph is unavailable in some contexts; fall back rather than fail outright -#}
        {%- set fallback = 'model.' ~ project_name ~ '.' ~ model_name -%}
        {{ log("dbt_query_profiler: graph unavailable, assuming node id '" ~ fallback ~ "'. Pass node_id= explicitly if this is wrong.", info=True) }}
        {{ return(fallback) }}
    {%- endif -%}

    {%- set matches = [] -%}
    {%- set near = [] -%}
    {%- set model_count = namespace(n=0) -%}
    {%- for unique_id, node in graph.nodes.items() -%}
        {%- if node.resource_type == 'model' -%}
            {%- set model_count.n = model_count.n + 1 -%}
            {%- if node.name == model_name -%}
                {%- do matches.append(unique_id) -%}
            {%- elif model_name | lower in (node.name | lower) -%}
                {%- do near.append(node.name) -%}
            {%- endif -%}
        {%- endif -%}
    {%- endfor -%}

    {%- if matches | length == 1 -%}
        {{ return(matches[0]) }}
    {%- elif matches | length > 1 -%}
        {{ exceptions.raise_compiler_error(
            "Model name '" ~ model_name ~ "' is ambiguous - it matches "
            ~ (matches | length) ~ " models: " ~ (matches | join(', '))
            ~ ". Pass node_id= with the one you want."
        ) }}
    {%- elif near -%}
        {{ exceptions.raise_compiler_error(
            "No model named '" ~ model_name ~ "'. Similar names: " ~ (near | join(', ')) ~ "."
        ) }}
    {%- else -%}
        {{ exceptions.raise_compiler_error(
            "No model named '" ~ model_name ~ "' among " ~ model_count.n
            ~ " models in the project. Check the name, or pass node_id= directly."
        ) }}
    {%- endif -%}
{% endmacro %}
