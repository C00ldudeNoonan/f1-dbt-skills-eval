{#-
  One row per telemetry sample. Incremental, replaced a race at a time
  (delete+insert on race_id).

  Each routine run:
    1. Finds the races that received raw rows since the last run: rows whose
       _LOADED_AT is later than the newest loaded_at here, minus var
       telemetry_lookback_hours for loads that commit out of order. The raw
       table is appended in load order, so this metadata query prunes to the
       newest micro-partitions.
    2. Re-reads only those races from raw (a literal race_id list, so
       Snowflake prunes partitions) and replaces them here.
  Late samples carry a new _LOADED_AT, so their race is rebuilt however old
  it is. Rebuilding whole races (not merging rows) also applies re-deliveries
  and corrections exactly. If a sample is delivered twice, the latest wins.

  The race list is computed in the model body, not in config(): Fusion fixes
  config at parse time, so a run-time incremental_predicates value is ignored.

  ingested_at = when this run wrote the race. mart_lap_telemetry_summary uses
  it to find races to recompute.
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

{%- set races_to_load = none -%}
{%- if is_incremental() -%}
    {%- set watermark = telemetry_watermark(this, 'loaded_at') -%}
    {%- if watermark -%}
        {%- set races_to_load = telemetry_race_list(
            source('telemetry', 'car_telemetry'), 'raceid',
            "_loaded_at > dateadd(hour, -" ~ var('telemetry_lookback_hours') ~ ", " ~ watermark ~ ")"
        ) -%}
    {%- endif -%}
{%- endif %}

with samples as (
    select *
    from {{ ref('stg_telemetry__car_telemetry') }}
    {% if races_to_load %}
    -- Races with new raw rows since the last run: {{ races_to_load }}
    where race_id in {{ races_to_load }}
    {% endif %}
)

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
    loaded_at,
    current_timestamp()::timestamp_ntz as ingested_at
from samples
qualify row_number() over (
    partition by race_id, driver_id, lap, sample_index
    order by loaded_at desc
) = 1
-- Written in race order so the table stays naturally clustered by race_id,
-- which keeps the per-race reads and deletes pruned.
order by race_id, driver_id, lap, sample_index
