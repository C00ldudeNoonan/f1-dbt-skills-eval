-- Thin view: renames only, so a `loaded_at` filter written downstream is pushed into the scan of the
-- raw table. No dedupe or joins here (the table is ~20M rows); the fact handles re-deliveries.
select
    raceid as race_id,
    driverid as driver_id,
    lap,
    sample_index,
    recorded_at,
    speed_kph,
    throttle_pct,
    brake,
    gear,
    drs,
    _loaded_at as loaded_at
from {{ source('telemetry', 'car_telemetry') }}
