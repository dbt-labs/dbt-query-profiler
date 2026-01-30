{{
    config(
        materialized='view',
        tags=['setup']
    )
}}

{#
    Placeholder model for DuckDB logging setup.
    Actual logging is enabled via on-run-start hook with file-based storage.
    For other adapters, this is just a placeholder.
#}

select 1 as logging_enabled
