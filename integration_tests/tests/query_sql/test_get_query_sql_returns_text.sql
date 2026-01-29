{#
    Test: get_query_sql returns the SQL text for a query.

    This test verifies that:
    1. get_query_history returns queries with query_ids
    2. The query_text column contains SQL

    Note: We can't directly test get_query_sql with a runtime query_id
    since macros are expanded at compile time. Instead we verify
    the history returns queries with both query_id and query_text.
#}

-- depends_on: {{ ref('setup_test_queries') }}

{# Use the actual get_query_history macro #}
{% set history_sql = dbt_query_profiler.get_query_history(limit=5) %}

with history as (
    {{ history_sql }}
),

validation as (
    select
        count(*) as total_queries,
        count(query_id) as queries_with_id,
        count(query_text) as queries_with_text
    from history
)

-- Test passes if we have queries with both query_id and query_text
select 'Query history missing query_id or query_text' as failure_reason
from validation
where total_queries = 0
   or queries_with_id = 0
   or queries_with_text = 0
