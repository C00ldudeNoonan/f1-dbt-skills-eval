{#
    session_date comes from the first ten characters of DATE_START (YYYY-MM-DD). That part is
    the reliable one: three sessions carry the \N sentinel inside the time part, which breaks the
    full timestamp. session_start_utc is kept as parsed, and may be null for those rows.
    tests/warn_vendor_b_malformed_session_timestamps.sql reports them.
#}
select
    {{ clean_null('session_key') }}::bigint as session_key,
    case lower({{ clean_null('session_type') }})
        when 'race' then 'race'
        when 'sprint' then 'sprint'
    end as session_type,
    {{ clean_null('meeting_name') }} as meeting_name,
    {{ clean_null('year') }}::integer as season,
    try_to_date(left({{ clean_null('date_start') }}, 10), 'YYYY-MM-DD') as session_date,
    try_to_timestamp_tz({{ clean_null('date_start') }}) as session_start_utc

from {{ source('vendor_b', 'vb_sessions') }}
