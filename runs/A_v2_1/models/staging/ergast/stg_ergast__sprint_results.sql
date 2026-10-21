select
    {{ to_int('resultid') }} as sprint_result_id,
    {{ to_int('raceid') }} as race_id,
    {{ to_int('driverid') }} as driver_id,
    {{ to_int('constructorid') }} as constructor_id,
    {{ to_int('number') }} as car_number,
    {{ to_int('grid') }} as grid,
    {{ clean_text('positiontext') }} as position_text,
    iff(regexp_like({{ clean_text('positiontext') }}, '[0-9]+'),
        {{ clean_text('positiontext') }}::integer, null) as finish_position,
    {{ to_int('position_order') }} as position_order,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ to_int('laps') }} as laps,
    {{ to_int('milliseconds') }} as race_time_ms,
    {{ to_int('fastestlap') }} as fastest_lap_number,
    {{ duration_to_ms('fastestlaptime') }} as fastest_lap_time_ms,
    {{ to_int('statusid') }} as status_id
from {{ source('ergast', 'sprint_results') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'driver_id'], 'sprint_result_id') }}
