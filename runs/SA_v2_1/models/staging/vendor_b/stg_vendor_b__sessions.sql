select distinct
    session_key::integer as session_key,
    lower({{ clean_text('session_type') }}) as session_type,
    {{ clean_text('meeting_name') }} as meeting_name,
    year::integer as season,
    -- the time part of date_start can be the `\N` marker, so only the date is used
    try_to_date(left({{ clean_text('date_start') }}, 10)) as session_date
from {{ source('vendor_b', 'vb_sessions') }}
