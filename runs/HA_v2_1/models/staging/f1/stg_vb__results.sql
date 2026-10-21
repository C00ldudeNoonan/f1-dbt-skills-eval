select
    {{ clean_null('SESSION_KEY') }}::bigint as session_key,
    {{ clean_null('DRIVER_KEY') }} as driver_key,
    {{ clean_null('TEAM_NAME') }} as team_name,
    {{ clean_null('GRID_POSITION') }}::int as grid_position,
    case when {{ clean_null('POSITION') }} rlike '^[0-9]+$' then {{ clean_null('POSITION') }}::int end as position_number,
    {{ clean_null('POSITION') }} as position_text,
    {{ clean_null('POINTS') }}::decimal(5, 1) as points
from ({{ dedupe_raw(source('f1_raw', 'VB_RESULTS'), none) }})
