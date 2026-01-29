

-- depends_on: "duck"."main"."setup_test_queries"




with history as (
    
    
    select
        query_id,
        message as query_text,
        cast(null as varchar) as user_name,
        cast(null as varchar) as warehouse_name,
        cast(null as varchar) as query_type,
        cast(null as varchar) as query_tag,
        timestamp as start_time,
        cast(null as bigint) as total_elapsed_time
    from duckdb_logs
    where type = 'QueryLog'
        and message not like '%dbt_query_profiler%'
    
    order by timestamp desc
    limit 5

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