{#
    Test: node_id filtering returns only the named model's statements.

    setup_test_queries and setup_second_model both contain the test marker, so a
    table_name substring match returns both. Filtering by node id must return only one.
    Also asserts at least one statement is returned, on adapters whose query history
    is immediate (duckdb, snowflake, bigquery) - otherwise an empty result set would
    pass this test having exercised nothing. Databricks and redshift query history
    lags execution by minutes, so a hard count there would be flaky; they are only
    checked by the negative assertion above.
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

{% if target.type in ['duckdb', 'snowflake', 'bigquery'] %}
union all

-- fails if the filter returned nothing at all
select 'node_id filter returned zero statements' as failure_reason
from (select count(*) as n from by_node) as counted
where n = 0
{% endif %}
