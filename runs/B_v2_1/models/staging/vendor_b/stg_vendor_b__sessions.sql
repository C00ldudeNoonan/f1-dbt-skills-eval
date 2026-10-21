select
    session_key::integer                        as session_key,
    lower(trim(session_type))                   as session_type,
    trim(meeting_name)                          as meeting_name,
    year::integer                               as season,
    -- Only the date is reliable: the time part is sometimes '\N'.
    try_to_date(left(trim(date_start), 10), 'YYYY-MM-DD') as session_date
from {{ source('vendor_b', 'vb_sessions') }}
{{ dedupe('session_key', 'session_key') }}
