{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['race_id', 'driver_id', 'lap']
    )
}}

-- One row per driver per lap. Incremental by *lap*: the laps touched by samples that landed since this
-- table last ran (new races and late arrivals alike) are recomputed in full from fct_telemetry and
-- replace their old rows; every other lap is left alone. The watermark is fct_telemetry's `ingested_at`
-- (our own write time, which also moves for reloaded rows), so nothing is missed even if a sample
-- landed with an old loaded_at.
{% if is_incremental() %}
with affected_laps as (

    select distinct race_id, driver_id, lap
    from {{ ref('fct_telemetry') }}
    where ingested_at > (select max(max_ingested_at) from {{ this }})

),

samples as (

    select telemetry.*
    from {{ ref('fct_telemetry') }} as telemetry
    inner join affected_laps
        on telemetry.race_id = affected_laps.race_id
        and telemetry.driver_id = affected_laps.driver_id
        and telemetry.lap = affected_laps.lap
    -- explicit race filter lets Snowflake prune the (race-clustered) fact to the affected races
    where telemetry.race_id in (select race_id from affected_laps)
)
{% else %}
with samples as (

    select * from {{ ref('fct_telemetry') }}

)
{% endif %}

select
    race_id,
    driver_id,
    lap,
    count(*) as samples,
    max(speed_kph) as max_speed_kph,
    avg(throttle_pct) as avg_throttle_pct,
    100.0 * count_if(throttle_pct >= 99) / count(*) as full_throttle_pct,
    count_if(brake) as brake_samples,
    max(ingested_at) as max_ingested_at
from samples
group by race_id, driver_id, lap
