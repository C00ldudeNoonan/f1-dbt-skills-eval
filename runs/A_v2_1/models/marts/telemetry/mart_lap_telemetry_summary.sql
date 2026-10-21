{#-
    One row per driver per lap of telemetry.

    Incremental and exact without full refreshes: a lap's figures depend on all
    of its samples, so any lap that received new samples is recomputed from
    scratch from fct_telemetry and merged over the old row.
      1. Touched laps come from the same narrow slice of raw telemetry that
         fct_telemetry just loaded (loaded_at above this table's high-water mark,
         up to fct_telemetry's own mark, so nothing not yet in the fact counts).
      2. Those laps are re-aggregated from fct_telemetry, filtered by race_id
         first so the read prunes to the affected races' micro-partitions.
    source_loaded_at (the latest sample loaded_at in the lap) is the high-water mark.
-#}
-- The staging ref below is only used on incremental runs; declare it so dbt
-- always knows the dependency.
-- depends_on: {{ ref('stg_telemetry__car_telemetry') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap'],
        cluster_by=['race_id'],
        on_schema_change='append_new_columns'
    )
}}

with telemetry as (

    select * from {{ ref('fct_telemetry') }}

),

{% if is_incremental() %}
touched_laps as (

    select distinct race_id, driver_id, lap
    from {{ ref('stg_telemetry__car_telemetry') }}
    where loaded_at > {{ telemetry_watermark(this, 'source_loaded_at') }}
        and loaded_at <= (select max(loaded_at) from {{ ref('fct_telemetry') }})

),

samples as (

    select telemetry.*
    from telemetry
    inner join touched_laps
        on telemetry.race_id = touched_laps.race_id
        and telemetry.driver_id = touched_laps.driver_id
        and telemetry.lap = touched_laps.lap
    -- Explicit race filter so Snowflake prunes fct_telemetry by its cluster key.
    where telemetry.race_id in (select race_id from touched_laps)

),
{% else %}
samples as (

    select * from telemetry

),
{% endif %}

laps as (

    select
        race_id,
        driver_id,
        lap,
        count(*) as samples,
        max(speed_kph) as max_speed_kph,
        avg(throttle_pct) as avg_throttle_pct,
        count_if(throttle_pct >= 99) / count(*) * 100 as full_throttle_pct,
        count_if(brake) as brake_samples,
        max(loaded_at) as source_loaded_at
    from samples
    group by 1, 2, 3

)

select
    race_id,
    driver_id,
    lap,
    samples::integer as samples,
    max_speed_kph::number(6, 1) as max_speed_kph,
    round(avg_throttle_pct, 2)::number(6, 2) as avg_throttle_pct,
    round(full_throttle_pct, 2)::number(6, 2) as full_throttle_pct,
    brake_samples::integer as brake_samples,
    source_loaded_at
from laps
