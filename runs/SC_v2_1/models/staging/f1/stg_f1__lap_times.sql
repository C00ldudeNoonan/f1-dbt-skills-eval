select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    lap::integer as lap,
    position::integer as position,
    milliseconds::integer as lap_time_ms
from {{ source('f1_raw', 'lap_times') }}
{{ dedupe(['race_id', 'driver_id', 'lap']) }}
