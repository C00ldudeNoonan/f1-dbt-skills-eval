select
    statusid::int       as status_id,
    status              as status
from {{ source('f1_raw', 'status') }}
