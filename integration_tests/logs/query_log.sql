-- created_at: 2026-01-29T13:05:40.420315+00:00
-- finished_at: 2026-01-29T13:05:46.086087+00:00
-- elapsed: 5.7s
-- outcome: success
-- dialect: snowflake
-- node_id: not available
-- query_id: 01c20e51-060a-bea5-0004-7d832cda3dbe
-- desc: execute adapter call
select
                query_id,
                execution_status,
                total_elapsed_time,
                bytes_scanned,
                rows_produced,
                bytes_written_to_result
            
            from table(information_schema.query_history(result_limit => 10000))
            
            where query_id = '01c20e51-060a-b073-0004-7d832cda87d2'
/* {"app": "dbt", "connection_name": "", "dbt_version": "2.0.0", "profile_name": "integration_tests", "target_name": "snow"} */;
