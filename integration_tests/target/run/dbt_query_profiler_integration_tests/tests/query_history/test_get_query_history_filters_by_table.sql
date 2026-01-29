
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  

-- depends_on: "duck"."main"."setup_test_queries"

with query_history as (
    
    
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
    
        and lower(message) like '%test_query_profiler_marker%'
    
    order by timestamp desc
    limit 10

),

validation as (
    select
        case when count(*) > 0 then 0 else 1 end as failure_count,
        count(*) as rows_found
    from query_history
)

-- Return rows only if test fails (zero queries found)
select 'No queries found containing marker: test_query_profiler_marker' as failure_reason
from validation
where failure_count > 0
  
  
      
    ) dbt_internal_test