select
    {{ clean_int('resultid') }} as result_id,
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_int('constructorid') }} as constructor_id,
    {{ clean_int('grid') }} as grid,
    {{ clean_int('position') }} as position,
    {{ clean_raw('positiontext') }} as position_text,
    {{ clean_int('position_order') }} as position_order,
    {{ clean_decimal('points') }} as points,
    {{ clean_int('laps') }} as laps,
    {{ lap_time_to_ms('fastestlaptime') }} as fastest_lap_time_ms,
    {{ clean_int('statusid') }} as status_id
from {{ source('f1_raw', 'results') }}
qualify row_number() over (partition by result_id order by result_id) = 1
