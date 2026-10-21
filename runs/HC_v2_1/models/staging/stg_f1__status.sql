select
    {{ null_if_sentinel('STATUSID') }}::integer as status_id,
    {{ null_if_sentinel('STATUS') }} as status_name
from {{ source('f1_raw', 'STATUS') }}
