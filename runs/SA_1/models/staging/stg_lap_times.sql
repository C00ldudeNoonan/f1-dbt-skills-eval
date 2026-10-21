select
    raceid::int as race_id,
    driverid::int as driver_id,
    lap::int as lap,
    position::int as position,
    milliseconds::int as lap_time_ms
from {{ source('f1_raw', 'lap_times') }}
