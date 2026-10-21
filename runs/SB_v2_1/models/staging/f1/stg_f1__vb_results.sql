-- Vendor B results. `position` is the numeric classified finishing position, null for DNF/DSQ and other
-- non-numeric codes (kept as `position_text`).
select
    {{ clean_raw('session_key') }} as session_key,
    {{ clean_raw('driver_key') }} as driver_key,
    {{ clean_raw('team_name') }} as team_name,
    {{ clean_int('grid_position') }} as grid,
    case when regexp_like({{ clean_raw('position') }}, '^[0-9]+$') then {{ clean_raw('position') }}::integer end as position,
    {{ clean_raw('position') }} as position_text,
    {{ clean_decimal('points') }} as points
from {{ source('f1_raw', 'vb_results') }}
qualify row_number() over (partition by session_key, driver_key order by session_key) = 1
