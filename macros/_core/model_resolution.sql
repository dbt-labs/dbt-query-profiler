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


{#
    SQL selecting the one statement to profile for a node.

    get_query_history already normalises query_id / start_time / total_elapsed_time
    across all five adapters and is used as a subquery by every print_query_history
    macro, so this needs no per-adapter implementation.

    "Slowest of the num_candidates most recent" is an approximation. dbt's default
    query comment carries no invocation_id and nothing else in query history marks a run
    boundary, so the actual latest run is not recoverable. Keep num_candidates small:
    widening it reaches back into older, slower runs.

    On DuckDB total_elapsed_time is always NULL (duckdb_logs has no duration), so
    `nulls last` falls through to the length(query_text) tiebreak, and then to
    most-recent. A table build emits several short housekeeping statements
    (rename, drop backup) alongside the one real create-as-select; among equally
    timeless candidates the longest statement is far more likely to be that one.
    This only affects adapters/rows where total_elapsed_time is NULL - adapters
    that report real durations are unaffected by the tiebreak.
#}
{% macro _node_query_id_sql(node_id, num_candidates=10) %}
    select
        query_id,
        query_type,
        total_elapsed_time,
        start_time
    from ({{ dbt_query_profiler.get_query_history(node_id=node_id, limit=num_candidates) }}) as recent_statements
    order by total_elapsed_time desc nulls last, length(query_text) desc, start_time desc
    limit 1
{% endmacro %}


{#
    Turn whichever of query_id / model_name / node_id the caller supplied into a query_id.
#}
{% macro resolve_query_id(query_id=none, model_name=none, node_id=none, num_candidates=10) %}
    {%- set supplied = [] -%}
    {%- if query_id is not none %}{% do supplied.append('query_id') %}{% endif -%}
    {%- if model_name is not none %}{% do supplied.append('model_name') %}{% endif -%}
    {%- if node_id is not none %}{% do supplied.append('node_id') %}{% endif -%}

    {%- if supplied | length > 1 -%}
        {{ exceptions.raise_compiler_error(
            "Pass exactly one of query_id, model_name or node_id - got " ~ (supplied | join(' and ')) ~ "."
        ) }}
    {%- elif supplied | length == 0 -%}
        {{ exceptions.raise_compiler_error("Pass one of query_id, model_name or node_id.") }}
    {%- endif -%}

    {%- if query_id is not none -%}
        {{ return(query_id) }}
    {%- endif -%}

    {%- set resolved_node_id = node_id if node_id is not none else dbt_query_profiler.resolve_node_id(model_name) -%}

    {%- if not execute -%}
        {{ return(none) }}
    {%- endif -%}

    {% do dbt_query_profiler.ensure_history_available() %}
    {%- set results = run_query(dbt_query_profiler._node_query_id_sql(resolved_node_id, num_candidates)) -%}

    {%- if not results or not results.rows -%}
        {{ exceptions.raise_compiler_error(
            "No queries found for " ~ resolved_node_id ~ ". Either the model has not run, "
            ~ "or it ran outside this adapter's query history window, or the project "
            ~ "overrides query_comment so node_id is not present in the executed SQL."
        ) }}
    {%- endif -%}

    {%- set row = results.rows[0] -%}
    {%- set duration = row[2] -%}
    {{ log("dbt_query_profiler: profiling " ~ resolved_node_id, info=True) }}
    {{ log("  chose query_id " ~ row[0] ~ " - " ~ (row[1] or 'unknown type')
           ~ (", " ~ duration ~ " ms" if duration is not none else ", duration unavailable on this adapter")
           ~ ", " ~ row[3], info=True) }}
    {{ return(row[0]) }}
{% endmacro %}
