{#
    Test: get_query_history filters by table_name.

    This test verifies that the table_name filter works by searching
    for queries containing our test marker.

    Test passes if at least one row is returned containing the marker.
    Test fails if zero rows are returned.
#}

-- depends_on: {{ ref('setup_test_queries') }}

with query_history as (
    {{ dbt_query_profiler.get_query_history(
        table_name=var('test_marker'),
        limit=10
    ) }}
),

validation as (
    select
        case when count(*) > 0 then 0 else 1 end as failure_count,
        count(*) as rows_found
    from query_history
)

-- Return rows only if test fails (zero queries found)
select 'No queries found containing marker: {{ var("test_marker") }}' as failure_reason
from validation
where failure_count > 0
