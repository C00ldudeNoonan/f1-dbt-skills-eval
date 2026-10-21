with source as (
    select * from {{ source('f1_raw', 'sprint_results') }}
)

select
    {{ to_integer('resultid') }} as result_id,
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('driverid') }} as driver_id,
    {{ to_integer('constructorid') }} as constructor_id,
    {{ to_integer('number') }} as car_number,
    -- 0 means the car started from the pit lane.
    {{ to_integer('grid') }} as grid,
    -- positiontext is the classification: a number when classified, otherwise
    -- a code (R retired, D disqualified, E excluded, W withdrew, F failed to
    -- qualify, N not classified). The raw position column is occasionally \N
    -- for classified finishers, so finish_position is derived from the text.
    {{ clean_text('positiontext') }} as position_text,
    {{ to_integer('positiontext') }} as finish_position,
    {{ to_integer('position_order') }} as position_order,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ to_integer('laps') }} as laps,
    {{ clean_text('time') }} as race_time_text,
    {{ to_integer('milliseconds') }} as race_time_ms,
    {{ to_integer('fastestlap') }} as fastest_lap_number,
    {{ time_to_ms('fastestlaptime') }} as fastest_lap_time_ms,
    {{ to_integer('statusid') }} as status_id
from source
{{ deduplicate('race_id, driver_id, position_order', 'result_id') }}
