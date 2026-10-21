select
    {{ clean_null('raceid') }}::integer as race_id,
    {{ clean_null('driverid') }}::integer as driver_id,
    {{ clean_null('stop') }}::integer as stop_number,
    {{ clean_null('lap') }}::integer as lap_number,
    {{ clean_null('milliseconds') }}::integer as pit_stop_ms

from {{ source('f1_raw', 'pit_stops') }}
