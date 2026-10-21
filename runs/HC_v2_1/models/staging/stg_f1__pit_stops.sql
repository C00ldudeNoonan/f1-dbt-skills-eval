select
    {{ null_if_sentinel('RACEID') }}::integer as race_id,
    {{ null_if_sentinel('DRIVERID') }}::integer as driver_id,
    {{ null_if_sentinel('STOP') }}::integer as stop_number,
    {{ null_if_sentinel('LAP') }}::integer as lap_number,
    {{ null_if_sentinel('MILLISECONDS') }}::integer as stop_duration_ms
from {{ source('f1_raw', 'PIT_STOPS') }}
