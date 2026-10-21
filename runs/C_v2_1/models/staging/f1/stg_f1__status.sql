with source as (
    select * from {{ source('f1_raw', 'status') }}
)

select
    {{ to_integer('statusid') }} as status_id,
    {{ clean_text('status') }} as status
from source
{{ deduplicate('status_id', 'status_id') }}
