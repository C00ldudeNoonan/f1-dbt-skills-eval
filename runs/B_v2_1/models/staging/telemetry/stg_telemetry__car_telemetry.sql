{#-
  View over the raw telemetry. Never select from it without a filter on
  loaded_at or race_id: it's ~20M rows. As a view it adds no storage, and
  filters from the incremental models push down to the raw table.
-#}
select
    raceid::integer             as race_id,
    driverid::integer           as driver_id,
    lap::integer                as lap,
    sample_index::integer       as sample_index,
    recorded_at,
    speed_kph::number(6, 1)     as speed_kph,
    throttle_pct::integer       as throttle_pct,
    brake,
    gear::integer               as gear,
    drs::integer                as drs,
    _loaded_at                  as loaded_at
from {{ source('telemetry', 'car_telemetry') }}
