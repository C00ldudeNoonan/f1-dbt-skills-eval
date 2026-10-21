select
    statusid::int as status_id,
    status
from {{ source('f1_raw', 'status') }}
