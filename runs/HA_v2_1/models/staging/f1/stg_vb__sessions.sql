select
    {{ clean_null('SESSION_KEY') }}::bigint as session_key,
    case {{ clean_null('SESSION_TYPE') }}
        when 'Race' then 'race'
        when 'Sprint' then 'sprint'
    end as session_type,
    {{ clean_null('MEETING_NAME') }} as meeting_name,
    {{ clean_null('YEAR') }}::int as season,
    try_to_date(substr({{ clean_null('DATE_START') }}, 1, 10)) as session_date
from ({{ dedupe_raw(source('f1_raw', 'VB_SESSIONS'), 'SESSION_KEY') }})
