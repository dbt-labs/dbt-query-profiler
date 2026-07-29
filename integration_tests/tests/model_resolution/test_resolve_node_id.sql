{#
    Test: resolve_node_id turns a model name into its unique_id via graph.nodes.
#}

-- depends_on: {{ ref('setup_test_queries') }}

{% set resolved = dbt_query_profiler.resolve_node_id('setup_test_queries') %}
{% set expected = 'model.dbt_query_profiler_integration_tests.setup_test_queries' %}

select 'resolve_node_id returned {{ resolved }}, expected {{ expected }}' as failure_reason
where '{{ resolved }}' != '{{ expected }}'
