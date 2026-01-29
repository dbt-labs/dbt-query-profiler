
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  

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
    
    order by timestamp desc
    limit 5

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
  
  
      
    ) dbt_internal_test