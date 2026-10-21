select
    {{ clean_null('raceid') }}::integer as race_id,
    {{ clean_null('driverid') }}::integer as driver_id,
    {{ clean_null('lap') }}::integer as lap_number,
    {{ clean_null('position') }}::integer as position,
    {{ clean_null('milliseconds') }}::integer as lap_ms

from {{ source('f1_raw', 'lap_times') }}
