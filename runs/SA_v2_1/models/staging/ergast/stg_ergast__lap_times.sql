select distinct
    raceid::integer as race_id,
    driverid::integer as driver_id,
    lap::integer as lap,
    {{ clean_text('position') }}::integer as position,
    {{ clean_text('milliseconds') }}::integer as lap_time_ms
from {{ source('ergast', 'lap_timing') }}
