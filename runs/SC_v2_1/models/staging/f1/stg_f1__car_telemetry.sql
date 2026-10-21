-- Thin view only: no de-duplication or windowing here, so filters on `loaded_at` from the
-- incremental models are pushed straight down to the raw table (partition pruning).
select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    lap::integer as lap,
    sample_index::integer as sample_index,
    recorded_at as recorded_at,
    speed_kph::number(6, 1) as speed_kph,
    throttle_pct::number(5, 1) as throttle_pct,
    brake as brake,
    gear::integer as gear,
    drs::integer as drs,
    _loaded_at as loaded_at
from {{ source('f1_raw', 'car_telemetry') }}
