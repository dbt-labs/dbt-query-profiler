
  
    



create or replace transient  table analytics.dbt_bperigaud.setup_test_queries
    
    
    
    as (



-- Depends on logging being enabled first (for DuckDB)
-- analytics.dbt_bperigaud.setup_enable_logging

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
    )
;




  