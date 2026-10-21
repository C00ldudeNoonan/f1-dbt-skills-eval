with cleaned as (
    select
        {{ clean_int('statusid') }} as status_id,
        {{ clean_text('status') }}  as status
    from {{ source('ergast', 'status') }}
)

select * from cleaned
{{ dedupe('status_id', 'status_id') }}
