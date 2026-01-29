{{
    config(
        materialized='view',
        tags=['setup'],
        pre_hook=["{% if target.type == 'duckdb' %}CALL enable_logging('QueryLog');{% endif %}"]
    )
}}

{#
    This model enables DuckDB logging before any test queries run.
    For other adapters, it's just a placeholder.
#}

select 1 as logging_enabled
