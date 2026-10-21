select
    {{ clean_int('resultid') }} as sprint_result_id,
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_int('constructorid') }} as constructor_id,
    {{ clean_int('grid') }} as grid,
    {{ clean_int('position') }} as position,
    {{ clean_raw('positiontext') }} as position_text,
    {{ clean_int('position_order') }} as position_order,
    {{ clean_decimal('points') }} as points,
    {{ clean_int('laps') }} as laps
from {{ source('f1_raw', 'sprint_results') }}
qualify row_number() over (partition by sprint_result_id order by sprint_result_id) = 1
