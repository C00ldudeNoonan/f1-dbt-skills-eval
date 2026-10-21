-- DURATION is inconsistently formatted (m:ss.mmm once a stop passes a minute),
-- so MILLISECONDS is the reliable measure.
select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    stop::integer as stop_number,
    lap::integer as lap,
    milliseconds::integer as duration_ms
from {{ source('f1_raw', 'pit_stops') }}
{{ dedupe(['race_id', 'driver_id', 'stop_number']) }}
