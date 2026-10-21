with source as (
    select * from {{ source('f1_raw', 'qualifying') }}
)

select
    {{ to_integer('qualifyid') }} as qualify_id,
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('driverid') }} as driver_id,
    {{ to_integer('constructorid') }} as constructor_id,
    {{ to_integer('number') }} as car_number,
    {{ to_integer('position') }} as qualifying_position,
    -- Missing session times arrive as \N or as empty strings.
    {{ time_to_ms('q1') }} as q1_ms,
    {{ time_to_ms('q2') }} as q2_ms,
    {{ time_to_ms('q3') }} as q3_ms
from source
{{ deduplicate('race_id, driver_id', 'qualify_id') }}
