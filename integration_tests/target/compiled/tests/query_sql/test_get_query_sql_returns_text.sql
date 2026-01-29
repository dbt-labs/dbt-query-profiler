

-- depends_on: analytics.dbt_bperigaud.setup_test_queries




with history as (
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