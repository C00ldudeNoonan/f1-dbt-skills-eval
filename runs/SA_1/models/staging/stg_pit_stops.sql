select
    raceid::int as race_id,
    driverid::int as driver_id,
    stop::int as stop_number,
    lap::int as lap,
    milliseconds::int as duration_ms
from {{ source('f1_raw', 'pit_stops') }}
