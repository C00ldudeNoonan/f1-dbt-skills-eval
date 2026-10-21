select
    statusid::integer as status_id,
    trim(status) as status
from {{ source('f1_raw', 'status') }}
{{ dedupe(['status_id']) }}
