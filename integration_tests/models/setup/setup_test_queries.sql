{{
    config(
        materialized='table',
        tags=['setup']
    )
}}

{#
    This model creates test data with a unique marker string.
    The query will appear in query history and can be used to test:
    - get_query_history (find this query by table_name filter)
    - get_query_sql (retrieve the SQL text)
    - get_query_plan (get execution plan)
    - get_query_stats (get execution statistics)

    The marker '{{ var("test_marker") }}' appears in the query text
    so we can filter for it in query history.
#}

-- Depends on logging being enabled first (for DuckDB)
-- {{ ref('setup_enable_logging') }}

select
    1 as id,
    '{{ var("test_marker") }}' as marker,
    current_timestamp as created_at
union all
select
    2 as id,
    '{{ var("test_marker") }}' as marker,
    current_timestamp as created_at
union all
select
    3 as id,
    '{{ var("test_marker") }}' as marker,
    current_timestamp as created_at
