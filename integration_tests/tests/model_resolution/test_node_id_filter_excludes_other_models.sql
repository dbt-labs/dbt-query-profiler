{#
    Test: node_id filtering returns only the named model's statements.

    setup_test_queries and setup_second_model both contain the test marker, so a
    table_name substring match returns both. Filtering by node id must return only one.
#}

-- depends_on: {{ ref('setup_test_queries') }}
-- depends_on: {{ ref('setup_second_model') }}

{% set node_id = 'model.dbt_query_profiler_integration_tests.setup_second_model' %}

with by_node as (
    {{ dbt_query_profiler.get_query_history(node_id=node_id, limit=20) }}
)

-- fails if any returned statement is not the requested model's
-- (BigQuery has no POSITION(x IN y) - see macros/bigquery/query_history.sql)
select 'node_id filter returned a statement for another model' as failure_reason
from by_node
{% if target.type == 'bigquery' %}
where strpos(query_text, '{{ node_id }}') = 0
{% else %}
where position('{{ node_id }}' in query_text) = 0
{% endif %}
