{#
    Test: resolve_node_id turns a model name into its unique_id via graph.nodes.
#}

-- depends_on: {{ ref('setup_test_queries') }}

{% set resolved = dbt_query_profiler.resolve_node_id('setup_test_queries') %}
{% set expected = 'model.dbt_query_profiler_integration_tests.setup_test_queries' %}

with resolution as (
    select 1 as dummy
)

select 'resolve_node_id returned {{ resolved }}, expected {{ expected }}' as failure_reason
from resolution
where '{{ resolved }}' != '{{ expected }}'
