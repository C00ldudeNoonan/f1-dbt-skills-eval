select
    {{ to_int('resultid') }} as result_id,
    {{ to_int('raceid') }} as race_id,
    {{ to_int('driverid') }} as driver_id,
    {{ to_int('constructorid') }} as constructor_id,
    {{ to_int('number') }} as car_number,
    {{ to_int('grid') }} as grid,
    {{ clean_text('positiontext') }} as position_text,
    -- Classified finishing position. Derived from position_text, not position:
    -- two classified lapped finishers in the 2005 Australian GP (race 71) have
    -- position \N but a numeric position_text. Letters (R, D, E, W, F, N) mean
    -- not classified. A digit regex is used because try_to_number('E') returns 0.
    iff(regexp_like({{ clean_text('positiontext') }}, '[0-9]+'),
        {{ clean_text('positiontext') }}::integer, null) as finish_position,
    {{ to_int('position_order') }} as position_order,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ to_int('laps') }} as laps,
    {{ clean_text('time') }} as race_time_text,
    {{ to_int('milliseconds') }} as race_time_ms,
    {{ to_int('fastestlap') }} as fastest_lap_number,
    {{ to_int('rank') }} as fastest_lap_rank,
    {{ duration_to_ms('fastestlaptime') }} as fastest_lap_time_ms,
    {{ to_decimal('fastestlapspeed', 8, 3) }} as fastest_lap_speed_kph,
    {{ to_int('statusid') }} as status_id
from {{ source('ergast', 'results') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['result_id'], 'result_id') }}
