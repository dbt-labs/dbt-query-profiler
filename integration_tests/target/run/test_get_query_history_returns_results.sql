
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  

with query_history as (
    select
        query_id,
        query_text,
        user_name,
        warehouse_name,
        query_type,
        query_tag,
        start_time,
        total_elapsed_time
    
    
    
    from table(information_schema.query_history_by_user(
        user_name => 'benoit_p',
        result_limit => 100
    ))
    
    where nvl(query_tag, '') != 'dbt_query_profiler'
    
    
    
    order by start_time desc
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