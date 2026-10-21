-- Vendor B sessions. session_date is the UTC calendar date of the start;
-- some sprint starts have no time ('T\NZ'), so the date is taken from the
-- first ten characters.
select
    session_key::integer as session_key,
    lower({{ clean_text('session_type') }}) as session_type,
    {{ clean_text('meeting_name') }} as meeting_name,
    year::integer as season,
    {{ to_date('left(date_start, 10)') }} as session_date,
    try_to_timestamp_ntz(replace(replace({{ clean_text('date_start') }}, 'T', ' '), 'Z', '')) as session_start_utc
from {{ source('vendor_b', 'vb_sessions') }}
{{ dedupe_on(['session_key'], 'session_key') }}
