{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        cluster_by=['race_id']
    )
}}

{#
    One row per car telemetry sample. Incremental by race.

    A routine run finds the races that received samples since the last load (see recent_loads_filter) and rebuilds
    each of those races in full from the raw samples. Late samples for an old race therefore land in that race, and
    the race's rows are replaced together, so a corrected or late sample never leaves stale rows behind.
    Only changed races are read, so the cost tracks the samples that changed, not the table size.
#}
with changed as (

    {{ changed_races_since_last_load(ref('stg_f1__car_telemetry'), 'loaded_at', 'loaded_at') }}

)

select
    telemetry.race_id,
    telemetry.driver_id,
    telemetry.lap,
    telemetry.sample_index,
    telemetry.recorded_at,
    telemetry.speed_kph,
    telemetry.throttle_pct,
    telemetry.brake,
    telemetry.gear,
    telemetry.drs,
    telemetry.loaded_at
from {{ ref('stg_f1__car_telemetry') }} as telemetry
where telemetry.race_id in (select race_id from changed)
