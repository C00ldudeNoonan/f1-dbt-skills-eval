with source as (
    select * from {{ source('f1_raw', 'pit_stops') }}
)

select
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('driverid') }} as driver_id,
    {{ to_integer('stop') }} as stop_number,
    {{ to_integer('lap') }} as lap,
    try_to_time({{ clean_text('time') }}) as stop_time_local,
    -- Integer milliseconds is the only duration the vendor sends (the
    -- redundant text duration column was dropped in October 2026).
    {{ to_integer('milliseconds') }} as duration_ms,
    {{ to_integer('milliseconds') }} / 1000 as duration_seconds
from source
{{ deduplicate('race_id, driver_id, stop_number', 'duration_ms') }}
