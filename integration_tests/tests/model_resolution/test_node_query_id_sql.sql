{#
    Test: _node_query_id_sql returns exactly one statement, and it is the *right*
    one - the statement that builds the model, not just any statement mentioning it.

    setup_test_queries' create-as-select is the only candidate whose query_text
    contains the test marker; housekeeping statements (rename, drop backup) do not.
    _node_query_id_sql does not expose query_text itself, so the picked query_id is
    joined back to get_query_history(node_id=...) to check it. A count(*) == 1 check
    alone would still pass if the `order by` clause were deleted and the wrong
    statement got picked - this asserts the marker is actually present.
#}

-- depends_on: {{ ref('setup_test_queries') }}

{% set node_id = 'model.dbt_query_profiler_integration_tests.setup_test_queries' %}

with picked as (
    {{ dbt_query_profiler._node_query_id_sql(node_id) }}
),

candidates as (
    {#- Wider than _node_query_id_sql's own candidate window, so the join below
       can't miss the row it picked - the picker's window is a subset of this one. -#}
    {{ dbt_query_profiler.get_query_history(node_id=node_id, limit=50) }}
),

picked_marker_count as (
    select count(*) as n
    from picked
    inner join candidates on picked.query_id = candidates.query_id
    where candidates.query_text like '%{{ var("test_marker") }}%'
)

select 'expected exactly 1 picked statement' as failure_reason
from (select count(*) as n from picked) as picked_count
where n != 1

union all

select 'picked statement does not build the model (missing test marker {{ var("test_marker") }})' as failure_reason
from picked_marker_count
where n != 1
