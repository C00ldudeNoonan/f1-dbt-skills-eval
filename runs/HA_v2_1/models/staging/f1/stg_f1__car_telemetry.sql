select
    raceid::int as race_id,
    driverid::int as driver_id,
    lap::int as lap,
    sample_index::bigint as sample_index,
    recorded_at,
    speed_kph::decimal(6, 1) as speed_kph,
    throttle_pct::int as throttle_pct,
    brake::boolean as brake,
    gear::int as gear,
    drs::int as drs,
    _loaded_at
from {{ source('f1_telemetry', 'CAR_TELEMETRY') }}
