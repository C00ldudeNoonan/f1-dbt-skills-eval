{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap']
    )
}}
{#
    Grain: one row per driver per lap. full_throttle_pct is the share of samples at 99% throttle or
    above, as a percentage.

    Each run finds the laps touched by recently loaded raw samples (loaded after the last run's latest
    sample, less a one-day lookback), then recomputes those laps from all their samples in fct_telemetry,
    which is clustered by race, driver and lap so each lap is a pruned lookup. A recomputed lap replaces the old row, so a late sample is counted once and nothing is
    double counted. Laps nobody touched are not read.
#}
with changed_laps as (

    -- Read recent loads from staging (raw, ordered by load time), not from fct_telemetry: fct is
    -- clustered by race, driver and lap, which would stop load-time pruning from working.
    select distinct race_id, driver_id, lap
    from {{ ref('stg_f1__car_telemetry') }}
    {% if is_incremental() %}
    where _loaded_at > (
        select dateadd(day, -1, max(max_loaded_at)) from {{ this }}
    )
    {% endif %}

),

samples as (

    select
        telemetry.race_id,
        telemetry.driver_id,
        telemetry.lap,
        telemetry.speed_kph,
        telemetry.throttle_pct,
        telemetry.brake,
        telemetry._loaded_at
    from {{ ref('fct_telemetry') }} as telemetry
    inner join changed_laps
        on telemetry.race_id = changed_laps.race_id
        and telemetry.driver_id = changed_laps.driver_id
        and telemetry.lap = changed_laps.lap

)

select
    race_id,
    driver_id,
    lap,
    count(*) as samples,
    max(speed_kph) as max_speed_kph,
    avg(throttle_pct) as avg_throttle_pct,
    100.0 * count_if(throttle_pct >= 99) / count(*) as full_throttle_pct,
    count_if(brake) as brake_samples,
    max(_loaded_at) as max_loaded_at
from samples
group by race_id, driver_id, lap
