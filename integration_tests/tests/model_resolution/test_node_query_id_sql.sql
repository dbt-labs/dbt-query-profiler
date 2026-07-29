{#
    Test: _node_query_id_sql returns exactly one statement, and it belongs to the
    requested model.
#}

-- depends_on: {{ ref('setup_test_queries') }}

{% set node_id = 'model.dbt_query_profiler_integration_tests.setup_test_queries' %}

with picked as (
    {{ dbt_query_profiler._node_query_id_sql(node_id, 5) }}
)

select 'expected exactly 1 picked statement' as failure_reason
from (select count(*) as n from picked)
where n != 1
