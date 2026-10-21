select
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_int('stop') }} as stop_number,
    {{ clean_int('lap') }} as lap,
    {{ clean_int('milliseconds') }} as duration_ms
from {{ source('f1_raw', 'pit_stops') }}
qualify row_number() over (partition by race_id, driver_id, stop_number order by race_id) = 1
