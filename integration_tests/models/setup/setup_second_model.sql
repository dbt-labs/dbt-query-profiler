{{
    config(
        materialized='table',
        tags=['setup']
    )
}}

{#
    A second model that also mentions the test marker in its SQL. Exists so tests can
    prove node_id filtering returns only the requested model's statements, where a
    table_name substring match would return both.
#}

select
    1 as id,
    '{{ var("test_marker") }}' as marker,
    'second' as source_model
