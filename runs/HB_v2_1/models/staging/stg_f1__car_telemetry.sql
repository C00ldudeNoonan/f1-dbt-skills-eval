select
    {{ clean_null('raceid') }}::integer as race_id,
    {{ clean_null('driverid') }}::integer as driver_id,
    {{ clean_null('lap') }}::integer as lap,
    {{ clean_null('sample_index') }}::integer as sample_index,
    recorded_at,
    speed_kph::float as speed_kph,
    throttle_pct::float as throttle_pct,
    brake,
    gear::integer as gear,
    drs::integer as drs,
    _loaded_at as loaded_at

from {{ source('f1_raw', 'car_telemetry') }}
