-- Vendor B sessions. `session_date` is the UTC calendar date of the start (date_start can have a missing
-- time part: `2021-07-17T\N Z`), `session_type` is lower-cased to 'race' / 'sprint'.
select
    {{ clean_raw('session_key') }} as session_key,
    lower({{ clean_raw('session_type') }}) as session_type,
    {{ clean_raw('meeting_name') }} as meeting_name,
    {{ clean_int('year') }} as season,
    try_to_date(left({{ clean_raw('date_start') }}, 10), 'YYYY-MM-DD') as session_date
from {{ source('f1_raw', 'vb_sessions') }}
qualify row_number() over (partition by session_key order by session_key) = 1
