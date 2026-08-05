{#
    Test: resolve_node_id turns a model name into its unique_id via graph.nodes.

    Asserting only `resolved == expected` doesn't discriminate: for a model defined
    directly in this project, resolve_node_id's graph-unavailable fallback
    ('model.' ~ project_name ~ '.' ~ model_name) constructs the exact same string as a
    real graph lookup would, so this test would pass identically whether the graph
    lookup ran or silently fell back - which is precisely the case resolve_node_id
    exists to get right for models that live in installed packages (see its docstring).

    So also assert that `graph` was actually populated at call time. resolve_node_id's
    fallback fires only when `graph is not defined or not graph or not
    graph.get('nodes')` - if all three of those are false here, the fallback provably
    did not produce `resolved`. The ideal discriminator would be a model living in an
    installed package, where the fallback and the graph lookup disagree, but that needs
    a second local package as a project fixture purely for this test - out of scope for
    what is a minor coverage gap; flag if that's wanted.

    Guarded by `execute`: this file is compiled at parse time too, when `graph` is
    legitimately empty. resolve_node_id logs a warning whenever its fallback fires, and
    without this guard that warning fired on every `dbt parse`/`dbt test`/run-operation,
    not just when this test actually runs. The dry-parse render is discarded, never
    executed - the `none`/`false` defaults below just keep it from erroring on undefined
    variables during that render.
#}

-- depends_on: {{ ref('setup_test_queries') }}

{% set expected = 'model.dbt_query_profiler_integration_tests.setup_test_queries' %}
{% set resolved = none %}
{% set graph_populated = false %}

{% if execute %}
    {% set resolved = dbt_query_profiler.resolve_node_id('setup_test_queries') %}
    {#- `and` short-circuits to the last operand's value, not a bool - graph.get('nodes')
       is a dict, and rendering a dict inline below would break the compiled SQL. Force
       each operand through a comparison so the result is a real boolean. -#}
    {% set graph_populated = (graph is defined) and (graph | length > 0) and (graph.get('nodes', {}) | length > 0) %}
{% endif %}

with resolution as (
    select 1 as dummy
)

select
    'resolve_node_id returned {{ resolved }}, expected {{ expected }}; graph_populated={{ graph_populated }}' as failure_reason
from resolution
where '{{ resolved }}' != '{{ expected }}' or {{ 'false' if graph_populated else 'true' }}
