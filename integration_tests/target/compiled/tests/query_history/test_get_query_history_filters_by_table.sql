



-- depends_on: analytics.dbt_bperigaud.setup_test_queries

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
    
    
        and lower(query_text) like '%test_query_profiler_marker%'
    
    
    order by start_time desc
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