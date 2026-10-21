-- Pass-through rename of the raw telemetry. Deliberately NO deduplication or window functions here: downstream
-- incremental models filter on `loaded_at` and a window in this view would stop that filter being pushed down
-- to the raw table's micro-partitions, forcing a full scan.
select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    lap::integer as lap,
    sample_index::integer as sample_index,
    recorded_at,
    speed_kph::number(6, 1) as speed_kph,
    throttle_pct::integer as throttle_pct,
    brake,
    gear::integer as gear,
    drs::integer as drs,
    _loaded_at as loaded_at
from {{ source('f1_telemetry', 'car_telemetry') }}
