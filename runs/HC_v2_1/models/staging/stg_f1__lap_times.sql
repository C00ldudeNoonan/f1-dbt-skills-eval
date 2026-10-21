select
    {{ null_if_sentinel('RACEID') }}::integer as race_id,
    {{ null_if_sentinel('DRIVERID') }}::integer as driver_id,
    {{ null_if_sentinel('LAP') }}::integer as lap_number,
    {{ null_if_sentinel('POSITION') }}::integer as lap_position,
    {{ null_if_sentinel('MILLISECONDS') }}::integer as lap_time_ms
from {{ source('f1_raw', 'LAP_TIMES') }}
