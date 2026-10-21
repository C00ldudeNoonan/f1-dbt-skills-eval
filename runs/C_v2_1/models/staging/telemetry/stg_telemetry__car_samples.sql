-- Car telemetry samples (about 4 per second per car, 2022 onwards). The raw
-- table is already typed, so this only renames. It's a view, so filters
-- applied downstream (fct_telemetry's race filter) are pushed down to the raw
-- table and prune its micro-partitions.

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
    _loaded_at as source_loaded_at
from {{ source('telemetry', 'car_telemetry') }}
