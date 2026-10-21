select
    {{ clean_null('session_key') }}::bigint as session_key,
    {{ clean_null('driver_key') }} as driver_key,
    {{ clean_null('team_name') }} as team_name,
    {{ clean_null('grid_position') }}::integer as grid_position,
    {{ clean_null('position') }} as position_text,
    try_cast({{ clean_null('position') }} as integer) as position,
    {{ clean_null('points') }}::float as points

from {{ source('vendor_b', 'vb_results') }}
