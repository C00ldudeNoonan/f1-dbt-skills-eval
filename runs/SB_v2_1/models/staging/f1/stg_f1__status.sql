select
    {{ clean_int('statusid') }} as status_id,
    {{ clean_raw('status') }} as status
from {{ source('f1_raw', 'status') }}
qualify row_number() over (partition by status_id order by status_id) = 1
