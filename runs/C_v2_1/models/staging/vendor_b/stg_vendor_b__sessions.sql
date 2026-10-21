-- Vendor B sessions (Grand Prix races and sprints). meeting_name is the
-- circuit location. The start time is missing (\N) for the 2021 sprints, so
-- the session date is kept separately from the timestamp.

with source as (
    select * from {{ source('f1_raw', 'vb_sessions') }}
)

select
    session_key,
    case {{ clean_text('session_type') }}
        when 'Race' then 'race'
        when 'Sprint' then 'sprint'
    end as session_type,
    {{ clean_text('meeting_name') }} as meeting_name,
    year as season,
    try_to_date(left({{ clean_text('date_start') }}, 10), 'YYYY-MM-DD') as session_date,
    try_to_timestamp_ntz({{ clean_text('date_start') }}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as session_start_utc
from source
{{ deduplicate('session_key', 'session_key') }}
