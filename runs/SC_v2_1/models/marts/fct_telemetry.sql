{#- Incremental by landing time (`_loaded_at`), NOT by recorded time, so samples that arrive
    weeks after the race are still picked up.
    Each run finds the races that received rows since the watermark (the newest `loaded_at` already
    here, minus a small overlap), then reloads those races whole (delete+insert by race_id): the raw
    read is pruned by landing time for the discovery step and by race for the load, and a reload
    also replaces corrected or re-sent samples. A merge on the sample key would touch fewer rows but
    cannot be pruned (config is resolved before the batch is known), so it scans the whole table. -#}
{% set watermark = telemetry_watermark(this) if is_incremental() else none %}
{% set affected_races = telemetry_affected_races(ref('stg_f1__car_telemetry'), watermark) if is_incremental() else '-1' %}

{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

select
    race_id,
    driver_id,
    lap,
    sample_index,
    recorded_at,
    speed_kph,
    throttle_pct,
    brake,
    gear,
    drs,
    loaded_at
from {{ ref('stg_f1__car_telemetry') }}
{% if is_incremental() %}
where race_id in ({{ affected_races }})
{% endif %}
-- a sample re-delivered: keep the latest delivery
qualify row_number() over (
    partition by race_id, driver_id, lap, sample_index
    order by loaded_at desc
) = 1
