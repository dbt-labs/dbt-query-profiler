
  
    
    

    create  table
      "duck"."main"."setup_test_queries__dbt_tmp"
  
    as (
      



-- Depends on logging being enabled first (for DuckDB)
-- "duck"."main"."setup_enable_logging"

select
    1 as id,
    'test_query_profiler_marker' as marker,
    current_timestamp as created_at
union all
select
    2 as id,
    'test_query_profiler_marker' as marker,
    current_timestamp as created_at
union all
select
    3 as id,
    'test_query_profiler_marker' as marker,
    current_timestamp as created_at
    );
  
  