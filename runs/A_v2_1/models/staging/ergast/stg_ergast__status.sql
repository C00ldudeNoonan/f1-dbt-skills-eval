select
    {{ to_int('statusid') }} as status_id,
    {{ clean_text('status') }} as status
from {{ source('ergast', 'status') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['status_id'], 'status_id') }}
