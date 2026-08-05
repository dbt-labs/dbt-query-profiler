{#
    Resolve a dbt model name to its node id (unique_id).

    dbt's default query_comment embeds node_id in every statement's SQL, which makes it
    an exact key for "this model's statements". Building the id by hand as
    "model.<project>.<model>" breaks for models that live in installed packages, so the
    graph is the source of truth where it is available.
#}
{% macro resolve_node_id(model_name) %}
    {%- if graph is not defined or not graph or not graph.get('nodes') -%}
        {#- The graph is empty at parse time, but callers return before reaching this, so
            arriving here means it is missing on the execute pass. Guessing
            "model.<project>.<name>" would be wrong for any model in an installed package -
            the case this macro exists to handle - so fail rather than resolve to a plausible
            lie. -#}
        {{ exceptions.raise_compiler_error(
            "Cannot resolve model_name '" ~ model_name ~ "': the dbt graph is unavailable. "
            ~ "Pass node_id= directly (e.g. node_id: model." ~ project_name ~ "." ~ model_name ~ ")."
        ) }}
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
    Turn the model_name / node_id filter pair accepted by get_query_history and
    print_query_history into a single node_id, or none if neither was supplied.

    Distinct from resolve_query_id below: those two macros *filter* history rather
    than *select* one statement, so model_name and node_id are optional filters
    like table_name or query_type - there is no query_id branch and no "exactly one
    required" rule, just "not both".
#}
{% macro _resolve_history_node_id(model_name=none, node_id=none) %}
    {%- if model_name is not none and node_id is not none -%}
        {{ exceptions.raise_compiler_error(
            "Pass at most one of model_name or node_id - got model_name and node_id."
        ) }}
    {%- endif -%}
    {%- if node_id is not none -%}
        {{ return(node_id) }}
    {%- elif model_name is not none -%}
        {#- graph is empty at parse time, and the SQL built here isn't executed then
            either, so resolving would only produce a value nobody uses. -#}
        {{ return(dbt_query_profiler.resolve_node_id(model_name) if execute else none) }}
    {%- else -%}
        {{ return(none) }}
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
{% macro _node_query_id_sql(node_id, num_candidates=10, result_limit=1000) %}
    /* {{ dbt_query_profiler._self_identifier() }} */
    select
        query_id,
        query_type,
        total_elapsed_time,
        start_time,
        query_text,
        count(*) over () as candidate_count
    from ({{ dbt_query_profiler.get_query_history(node_id=node_id, limit=num_candidates, result_limit=result_limit) }}) as recent_statements
    order by total_elapsed_time desc nulls last, length(query_text) desc, start_time desc
    limit 1
{% endmacro %}


{#
    Turn whichever of query_id / model_name / node_id the caller supplied into a query_id.

    result_limit governs how far back through history the resolution query looks when
    gathering num_candidates for a model_name/node_id (mirrors get_query_history's own
    result_limit - see there for why it only affects Snowflake). Default 1000, not
    get_query_history's 100: that default suits browsing (a caller-chosen page size), but
    resolution is searching for one node's statements among *all* of a user's recent
    statements, so it needs a wide window - a real `dbt build` easily emits more than 100
    statements. 1000 matches get_query_sql's existing default and sits well inside
    Snowflake's documented 10000 cap. Callers with their own, differently-scoped
    result_limit (get_query_sql, get_query_stats) thread that value through instead of
    exposing a second one - see those macros.
#}
{% macro resolve_query_id(query_id=none, model_name=none, node_id=none, num_candidates=10, result_limit=1000) %}
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

    {#- Nothing below can work at parse time: run_query is a no-op then. Return before
        resolving, so parse doesn't pay for a lookup whose result is discarded. -#}
    {%- if not execute -%}
        {{ return(none) }}
    {%- endif -%}

    {%- set resolved_node_id = node_id if node_id is not none else dbt_query_profiler.resolve_node_id(model_name) -%}

    {% do dbt_query_profiler.ensure_history_available() %}
    {%- set results = run_query(dbt_query_profiler._node_query_id_sql(resolved_node_id, num_candidates, result_limit)) -%}

    {%- if not results or not results.rows -%}
        {{ exceptions.raise_compiler_error(
            "No queries found for " ~ resolved_node_id ~ ". Either the model has not run, "
            ~ "or more than result_limit (" ~ result_limit ~ ") other statements have run "
            ~ "since it did - raise result_limit - or it ran outside this adapter's query "
            ~ "history retention window, or the project overrides query_comment so node_id "
            ~ "is not present in the executed SQL."
        ) }}
    {%- endif -%}

    {%- set row = results.rows[0] -%}
    {%- set duration = row[2] -%}
    {%- set candidate_count = row[5] -%}
    {#- Every dbt-emitted statement starts with the same query_comment - previewing it
       verbatim would show a constant string regardless of which statement won, which
       defeats the point of the preview. Strip it first so the preview is the SQL
       itself (COMMIT/BEGIN and similar have no comment to strip). -#}
    {%- set raw_text = (row[4] | string).lstrip() -%}
    {%- set sql_only = raw_text.partition('*/')[2] if raw_text.startswith('/*') else raw_text -%}
    {#- Redshift's sys_query_history.query_text stores literal two-character `\n`/`\r`/`\t`
       escape sequences instead of real whitespace characters, so `\s+` below - which only
       matches real whitespace - leaves them uncollapsed and the preview is escape noise
       instead of SQL. Replace the literal sequences with a space first so both real and
       escaped whitespace normalise the same way. Do not remove this as redundant with the
       `\s+` collapse - it isn't, on Redshift specifically. -#}
    {%- set sql_only = sql_only.replace('\\n', ' ').replace('\\r', ' ').replace('\\t', ' ') -%}
    {%- set sql_preview_raw = modules.re.sub('\s+', ' ', sql_only).strip() -%}
    {%- set sql_preview = (sql_preview_raw[:60] ~ '...') if (sql_preview_raw | length) > 60 else sql_preview_raw -%}
    {{ log("dbt_query_profiler: profiling " ~ resolved_node_id, info=True) }}
    {{ log("  chose query_id " ~ row[0] ~ " - " ~ (row[1] or 'unknown type')
           ~ (", " ~ duration ~ " ms" if duration is not none else ", duration unavailable on this adapter")
           ~ ", " ~ row[3]
           ~ " (slowest of " ~ candidate_count ~ " recent statement" ~ ('' if candidate_count == 1 else 's') ~ " for this model)"
           ~ " - " ~ sql_preview, info=True) }}
    {{ return(row[0]) }}
{% endmacro %}
