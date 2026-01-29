{#
    Test: get_query_history returns results when queries exist.

    This test verifies that:
    1. The macro returns a valid SQL query
    2. The query returns at least one row

    Test passes if at least one row is returned.
    Test fails if zero rows are returned.
#}

with query_history as (
    {{ dbt_query_profiler.get_query_history(limit=5) }}
),

validation as (
    select
        case when count(*) > 0 then 0 else 1 end as failure_count
    from query_history
)

-- Return rows only if test fails (no queries found)
select 'get_query_history returned zero rows' as failure_reason
from validation
where failure_count > 0
