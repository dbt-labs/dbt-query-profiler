{% macro snowflake__get_execution_plan(query_id) %}
    select
        operator_id,
        parent_operators,
        operator_type,
        operator_statistics,
        execution_time_breakdown,
        operator_attributes
    from table(get_query_operator_stats('{{ query_id }}'))
    order by operator_id
{% endmacro %}


{#
    Shared expression fragments, so the semi-structured paths they read exist
    in exactly one place instead of being retyped in every branch that needs
    them. A typo in one of these would silently read as NULL forever - the
    print macros below already nvl() every column to '-', so a broken path
    looks identical to "nothing to report" rather than erroring.
#}
{% macro snowflake__overall_pct_expr() %}
    {{ return('execution_time_breakdown:"overall_percentage"::float') }}
{% endmacro %}


{% macro snowflake__spill_local_expr() %}
    {{ return('operator_statistics:"spilling":"bytes_spilled_local_storage"') }}
{% endmacro %}


{% macro snowflake__spill_remote_expr() %}
    {{ return('operator_statistics:"spilling":"bytes_spilled_remote_storage"') }}
{% endmacro %}


{#
    Shared min_pct/top_n filter fragments for snowflake__print_execution_plan.
    Split into WHERE and ORDER BY/LIMIT because the json format's non-top_n
    branch only needs the WHERE half - its ordering comes from array_agg's own
    "within group (order by ...)", not a query-level ORDER BY.
#}
{% macro snowflake__execution_plan_where_clause(pct_expr, min_pct) %}
    {%- if min_pct is not none %}
    where nvl({{ pct_expr }} * 100, 0) >= {{ min_pct }}
    {%- endif %}
{% endmacro %}


{% macro snowflake__execution_plan_order_limit_clause(order_expr, top_n) %}
    order by {{ order_expr }}
    {%- if top_n is not none %}
    limit {{ top_n }}
    {%- endif %}
{% endmacro %}


{% macro snowflake__print_execution_plan(query_id, format, min_pct=none, top_n=none) %}

    {#
        min_pct/top_n turn a wide plan (100+ operators, most at 0% time) into
        a shortlist of the operators actually worth looking at. Both filter
        on the same overall_percentage already shown, just re-read as a raw
        expression (Snowflake allows filtering/ordering on the semi-structured
        path directly, no need to alias or CTE it). Order stays by
        operator_id - the plan's natural top-to-bottom order - unless either
        arg is passed, at which point sorting by time% descending is what
        makes the filter useful.
    #}
    {%- set pct_expr = dbt_query_profiler.snowflake__overall_pct_expr() -%}
    {%- set order_by_pct = min_pct is not none or top_n is not none -%}
    {%- set order_expr = (pct_expr ~ ' desc') if order_by_pct else 'operator_id' -%}
    {%- set where_clause = dbt_query_profiler.snowflake__execution_plan_where_clause(pct_expr, min_pct) -%}
    {%- set order_limit_clause = dbt_query_profiler.snowflake__execution_plan_order_limit_clause(order_expr, top_n) -%}

    {% if format == 'text' %}
        {% set query %}
            select
                operator_id,
                operator_type,
                nvl(operator_statistics:"input_rows"::varchar, '-') as input_rows,
                nvl(operator_statistics:"output_rows"::varchar, '-') as output_rows,
                nvl(round({{ pct_expr }} * 100, 1)::varchar, '-') as pct
            from table(get_query_operator_stats('{{ query_id }}'))
            {{ where_clause }}
            {{ order_limit_clause }}
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% for row in results.rows %}
                {{ print("[" ~ row[0] ~ "] " ~ row[1] ~ "  (in: " ~ row[2] ~ ", out: " ~ row[3] ~ ", time: " ~ row[4] ~ "%)") }}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}

    {% elif format == 'markdown' %}
        {% set query %}
            select
                operator_id,
                operator_type,
                operator_statistics:"input_rows"::number as input_rows,
                operator_statistics:"output_rows"::number as output_rows,
                {{ pct_expr }} as pct
            from table(get_query_operator_stats('{{ query_id }}'))
            {{ where_clause }}
            {{ order_limit_clause }}
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {{ print("| ID | Operator | Input Rows | Output Rows | Time % |") }}
            {{ print("|---:|:---------|----------:|----------:|------:|") }}
            {% for row in results.rows %}
                {%- set input_rows = row[2] if row[2] is not none else '-' -%}
                {%- set output_rows = row[3] if row[3] is not none else '-' -%}
                {%- set pct = (row[4] * 100) | round(1) if row[4] is not none else '-' -%}
                {{ print("| " ~ row[0] ~ " | " ~ row[1] ~ " | " ~ input_rows ~ " | " ~ output_rows ~ " | " ~ pct ~ " |") }}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}

    {% else %}
        {# JSON format (default) #}
        {%- set object_expr -%}
            object_construct(
                'operator_id', operator_id,
                'parent_operators', parent_operators,
                'operator_type', operator_type,
                'operator_statistics', parse_json(operator_statistics),
                'execution_time_breakdown', parse_json(execution_time_breakdown),
                'operator_attributes', parse_json(operator_attributes)
            )
        {%- endset -%}

        {% if top_n is not none %}
            {#
                top_n needs LIMIT applied before array_agg aggregates everything,
                so (only in this case) the source becomes a subquery instead of
                staying a flat select like every other branch here.
            #}
            {% set query %}
                select
                    array_agg({{ object_expr }}) within group (order by {{ order_expr }}) as plan_json
                from (
                    select *
                    from table(get_query_operator_stats('{{ query_id }}'))
                    {{ where_clause }}
                    {{ order_limit_clause }}
                ) top_operators
            {% endset %}
        {% else %}
            {% set query %}
                select
                    array_agg({{ object_expr }}) within group (order by {{ order_expr }}) as plan_json
                from table(get_query_operator_stats('{{ query_id }}'))
                {{ where_clause }}
            {% endset %}
        {% endif %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}
    {% endif %}

{% endmacro %}


{% macro snowflake__get_execution_plan_summary(query_id) %}
    select
        operator_id,
        operator_type,
        operator_statistics:"input_rows"::number as input_rows,
        operator_statistics:"output_rows"::number as output_rows,
        operator_statistics:"spilling"::object as spilling_info,
        {{ dbt_query_profiler.snowflake__overall_pct_expr() }} as overall_percentage
    from table(get_query_operator_stats('{{ query_id }}'))
    order by operator_id
{% endmacro %}


{#
    print_execution_plan already has a json/text/markdown "raw plan" view -
    this is the condensed one, adding the two spilling byte counts that are
    the actual evidence for a warehouse-sizing decision (spilling means the
    warehouse was memory-constrained for this query). print_execution_plan
    never shows this outside its json format's raw operator_statistics blob,
    which is impractical to read on a plan with many operators.
#}
{% macro snowflake__print_execution_plan_summary(query_id, format) %}

    {%- set pct_expr = dbt_query_profiler.snowflake__overall_pct_expr() -%}
    {%- set spill_local_expr = dbt_query_profiler.snowflake__spill_local_expr() -%}
    {%- set spill_remote_expr = dbt_query_profiler.snowflake__spill_remote_expr() -%}

    {% if format == 'text' %}
        {% set query %}
            select
                operator_id,
                operator_type,
                nvl(operator_statistics:"input_rows"::varchar, '-') as input_rows,
                nvl(operator_statistics:"output_rows"::varchar, '-') as output_rows,
                nvl(round({{ pct_expr }} * 100, 1)::varchar, '-') as pct,
                nvl({{ spill_local_expr }}::varchar, '-') as spill_local,
                nvl({{ spill_remote_expr }}::varchar, '-') as spill_remote
            from table(get_query_operator_stats('{{ query_id }}'))
            order by operator_id
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {% for row in results.rows %}
                {{ print("[" ~ row[0] ~ "] " ~ row[1] ~ "  (in: " ~ row[2] ~ ", out: " ~ row[3] ~ ", time: " ~ row[4] ~ "%, spill_local: " ~ row[5] ~ ", spill_remote: " ~ row[6] ~ ")") }}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}

    {% elif format == 'markdown' %}
        {% set query %}
            select
                operator_id,
                operator_type,
                operator_statistics:"input_rows"::number as input_rows,
                operator_statistics:"output_rows"::number as output_rows,
                {{ pct_expr }} as pct,
                {{ spill_local_expr }}::number as spill_local,
                {{ spill_remote_expr }}::number as spill_remote
            from table(get_query_operator_stats('{{ query_id }}'))
            order by operator_id
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows %}
            {{ print("| ID | Operator | Input Rows | Output Rows | Time % | Spill Local (bytes) | Spill Remote (bytes) |") }}
            {{ print("|---:|:---------|----------:|----------:|------:|------:|------:|") }}
            {% for row in results.rows %}
                {%- set input_rows = row[2] if row[2] is not none else '-' -%}
                {%- set output_rows = row[3] if row[3] is not none else '-' -%}
                {%- set pct = (row[4] * 100) | round(1) if row[4] is not none else '-' -%}
                {%- set spill_local = row[5] if row[5] is not none else '-' -%}
                {%- set spill_remote = row[6] if row[6] is not none else '-' -%}
                {{ print("| " ~ row[0] ~ " | " ~ row[1] ~ " | " ~ input_rows ~ " | " ~ output_rows ~ " | " ~ pct ~ " | " ~ spill_local ~ " | " ~ spill_remote ~ " |") }}
            {% endfor %}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}

    {% else %}
        {# JSON format (default) #}
        {% set query %}
            select
                array_agg(
                    object_construct(
                        'operator_id', operator_id,
                        'operator_type', operator_type,
                        'input_rows', operator_statistics:"input_rows"::number,
                        'output_rows', operator_statistics:"output_rows"::number,
                        'overall_percentage', {{ pct_expr }},
                        'spilling_info', operator_statistics:"spilling"::object
                    )
                ) within group (order by operator_id) as plan_json
            from table(get_query_operator_stats('{{ query_id }}'))
        {% endset %}

        {% set results = run_query(query) %}

        {% if execute and results and results.rows and results.rows[0][0] %}
            {{ print(results.rows[0][0]) }}
        {% else %}
            {{ print("No execution plan found") }}
        {% endif %}
    {% endif %}

{% endmacro %}
