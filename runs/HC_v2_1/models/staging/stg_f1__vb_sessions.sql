{#
    Vendor B sessions. Grand Prix sessions are 'Race' and sprints are 'Sprint'. date_start is an ISO timestamp in UTC.
    Its time part can be \N, so the date is taken from the first ten characters.
#}
select
    SESSION_KEY::varchar as session_key,
    lower(trim(SESSION_TYPE)) as session_type,
    YEAR::integer as season,
    trim(MEETING_NAME) as meeting_name,
    try_to_date(substr(DATE_START, 1, 10), 'YYYY-MM-DD') as session_date
from {{ source('vendor_b', 'VB_SESSIONS') }}
