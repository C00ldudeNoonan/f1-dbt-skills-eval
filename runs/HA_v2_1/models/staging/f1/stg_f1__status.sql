select
    {{ clean_null('STATUSID') }}::int as status_id,
    {{ clean_null('STATUS') }} as status
from ({{ dedupe_raw(source('f1_raw', 'STATUS'), 'STATUSID') }})
