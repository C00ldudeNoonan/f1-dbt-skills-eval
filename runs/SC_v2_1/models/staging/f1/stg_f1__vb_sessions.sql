select
    trim(session_key) as session_key,
    lower(trim(session_type)) as session_type,
    trim(meeting_name) as meeting_name,
    year::integer as season,
    -- the time part is sometimes missing (`2024-11-30T\N`Z) while the date is present
    try_to_date(left(trim(date_start), 10), 'YYYY-MM-DD') as session_date,
    try_to_timestamp({{ clean_raw('date_start') }}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as started_at
from {{ source('f1_raw', 'vb_sessions') }}
{{ dedupe(['session_key']) }}
