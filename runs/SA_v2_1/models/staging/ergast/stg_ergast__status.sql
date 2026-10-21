select distinct
    statusid::integer as status_id,
    {{ clean_text('status') }} as status
from {{ source('ergast', 'status') }}
