{#
    Regression test: get_query_history(node_id=...) must match the node id only in its
    keyed form, as it appears in dbt's query comment - `"node_id": "<id>"` - not a bare
    mention that merely puts the id in double quotes without that key, and not a
    single-quoted SQL literal either. See _node_id_needle() in
    macros/_core/query_history.sql.

    The double-quoted-without-key form is not a hypothetical: it is exactly what defeated
    resolution on live Redshift before this test existed in its current form. A
    hand-written diagnostic query that merely mentioned a node id in double quotes (no
    key) ran for 5.7s; statement selection ranks candidates by duration, so it outranked
    the node's own 227ms CTAS - a silent wrong answer. Anchoring on the bare quotes alone
    (this test's previous form) could not tell those two cases apart; anchoring on the
    keyed form can.

    Computed entirely in Jinja/run_query, then rendered as a trivial static assertion
    (same pattern as test_resolve_node_id.sql), rather than as one compiled SQL statement,
    for two reasons:
    1. snowflake__get_query_history now filters out anything but
       execution_status = 'SUCCESS', which excludes a query from matching *itself* while
       it is still running (it cannot have completed with SUCCESS before it finishes).
       That is not enough on its own, though: the two check queries below embed the
       keyed node id and the poison marker as literals in their own SQL text, and
       once THIS test run finishes, those two queries themselves become ordinary completed,
       successful rows in history - indistinguishable from real matches on any later run of
       this same test (Snowflake's default retention is 7 days). Tagging the session with
       the package's self-identifier (the same mechanism print_query_history uses) is what
       excludes them, this run and every later one - the SUCCESS filter alone does not.
    2. Building the poison statement and re-querying history are two separate statements
       either way (a single SQL statement can't run_query a side effect mid-select), so
       there is no portability cost to doing the comparison in Jinja too.

    Two checks:
    1. Every statement get_query_history(node_id=...) currently returns must contain the
       keyed needle (true by construction when the filter is correct).
    2. A throwaway statement is executed that mentions the node id in double quotes but
       without the `"node_id":` key - the form that actually defeated the old anchoring on
       Redshift (dbt's own query comment on this throwaway reflects the currently-running
       test, not setup_second_model, so it carries no keyed reference either), tagged with
       a marker unique to this test run. Filtering by node_id AND that marker must then
       return nothing - if it does, the node_id filter matched on the bare double-quoted
       substring rather than the anchored, keyed form.

    Both checks only run on adapters whose query history is immediate (duckdb, snowflake,
    bigquery) - see test_node_id_filter_excludes_other_models.sql for why databricks and
    redshift, whose history lags execution by minutes, are excluded: the poison statement
    would not be visible yet, and the check would pass having exercised nothing.
#}

-- depends_on: {{ ref('setup_second_model') }}

{% set node_id = 'model.dbt_query_profiler_integration_tests.setup_second_model' %}
{% set needle = '"node_id": "' ~ node_id ~ '"' %}
{% set poison_marker = 'dbt_query_profiler_anchor_poison_' ~ invocation_id %}
{% set failure = namespace(reason=none) %}

{% if execute and target.type in ['duckdb', 'snowflake', 'bigquery'] %}

    {#
        Inject the poison BEFORE tagging the session - it must be a normal, untagged
        statement, indistinguishable from a real one, or the self-exclusion filter
        below would hide it too and this check would pass vacuously.

        The poison mentions the node id in double quotes but without the `"node_id":`
        key - a bare `'"<id>"'` SQL string literal, not `'<id>'`. A single-quoted-only
        mention was the old attack vector (defeated by the original bare-quotes
        anchoring); this one is the current attack vector (only defeated once the key
        was added) - see the file-level comment.
    #}
    {% set poison_sql %}
        select '{{ poison_marker }}' as marker, '"{{ node_id }}"' as fake_reference
    {% endset %}
    {% do run_query(poison_sql) %}

    {#
        Tag this session so get_query_history's query_tag self-exclusion filter hides
        only the two check queries below (the same mechanism print_query_history uses),
        not the poison statement above. See the file-level comment: this is still needed
        even with the execution_status = 'SUCCESS' filter, because on a later run these
        two queries are themselves completed, successful rows that embed the same
        literals they're searching for.
    #}
    {% if target.type == 'snowflake' %}
        {% do run_query("ALTER SESSION SET QUERY_TAG = '" ~ dbt_query_profiler._self_identifier() ~ "'") %}
    {% endif %}

    {% set by_node_results = run_query(dbt_query_profiler.get_query_history(node_id=node_id, limit=20)) %}
    {% for row in by_node_results.rows %}
        {% if needle not in row[1] %}
            {% set failure.reason = 'node_id filter returned a statement without the keyed node id' %}
        {% endif %}
    {% endfor %}

    {% set poisoned_results = run_query(dbt_query_profiler.get_query_history(node_id=node_id, table_name=poison_marker, limit=5, result_limit=1000)) %}
    {% if poisoned_results.rows | length > 0 %}
        {% set failure.reason = 'node_id filter matched a double-quoted mention of the node id without the query-comment key (anchoring broken)' %}
    {% endif %}

    {% if target.type == 'snowflake' %}
        {% do run_query("ALTER SESSION UNSET QUERY_TAG") %}
    {% endif %}

{% endif %}

with check_result as (
    select 1 as dummy
)

select '{{ failure.reason }}' as failure_reason
from check_result
where {{ 'true' if failure.reason is not none else 'false' }}
