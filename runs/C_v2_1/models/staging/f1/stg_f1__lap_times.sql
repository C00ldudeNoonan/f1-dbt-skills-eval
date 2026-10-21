with source as (
    select * from {{ source('f1_raw', 'lap_timing') }}
)

select
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('driverid') }} as driver_id,
    {{ to_integer('lap') }} as lap,
    {{ to_integer('position') }} as position,
    {{ to_integer('milliseconds') }} as lap_time_ms
from source
{{ deduplicate('race_id, driver_id, lap', 'lap_time_ms') }}
