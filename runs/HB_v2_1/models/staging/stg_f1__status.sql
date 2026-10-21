select
    {{ clean_null('statusid') }}::integer as status_id,
    {{ clean_null('status') }} as status

from {{ source('f1_raw', 'status') }}
