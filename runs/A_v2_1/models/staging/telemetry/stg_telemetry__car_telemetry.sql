-- Renamed view over the raw telemetry. A view on purpose: predicates on
-- loaded_at in downstream incremental models push down to the raw table, so
-- only the newly loaded micro-partitions are scanned.
select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    lap::integer as lap,
    sample_index::integer as sample_index,
    recorded_at,
    speed_kph::number(6, 1) as speed_kph,
    throttle_pct::integer as throttle_pct,
    brake::boolean as brake,
    gear::integer as gear,
    drs::integer as drs,
    _loaded_at as loaded_at
from {{ source('telemetry', 'car_telemetry') }}
