
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  

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



stats_check as (
    select count(*) as cnt
    from duckdb_logs
    where type = 'QueryLog'
)


-- Test passes if we found queries with stats
select 'No queries found to retrieve stats from' as failure_reason
from stats_check
where cnt = 0
  
  
      
    ) dbt_internal_test