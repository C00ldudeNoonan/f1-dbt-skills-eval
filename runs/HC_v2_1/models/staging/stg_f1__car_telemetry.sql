{#
    Car telemetry samples, about four per second per car, from 2022. _LOADED_AT is when the sample landed in
    our warehouse, not when it was recorded. Late samples carry a recent load time, so loaded_at is the incremental
    watermark. recorded_at is when the car recorded it.
#}
select
    RACEID::integer as race_id,
    DRIVERID::integer as driver_id,
    LAP::integer as lap,
    SAMPLE_INDEX::integer as sample_index,
    RECORDED_AT as recorded_at,
    SPEED_KPH::numeric(7, 3) as speed_kph,
    THROTTLE_PCT::numeric(5, 2) as throttle_pct,
    BRAKE::boolean as brake,
    GEAR::integer as gear,
    DRS::integer as drs,
    _LOADED_AT as loaded_at
from {{ source('f1_raw', 'CAR_TELEMETRY') }}
