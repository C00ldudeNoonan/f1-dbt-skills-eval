-- Grain: one row per driver per lap. Incremental and always correct without full refreshes.
--
-- A lap's summary must be recomputed from ALL of its samples whenever ANY sample for it is new or corrected, so
-- each run (1) finds the laps touched by samples loaded since this table's high-water mark (`last_loaded_at`,
-- minus the lookback), (2) re-aggregates exactly those laps from fct_telemetry (pruned to their races), and
-- (3) merges them by key. Late samples for an old lap therefore fix that lap's row and nothing else.
{% set cutoff = telemetry_cutoff('last_loaded_at') %}
{% set affected_races = telemetry_affected(ref('fct_telemetry'), 'race_id', cutoff) %}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap'],
        incremental_predicates=["DBT_INTERNAL_DEST.race_id in (select distinct race_id from " ~ this ~ "__dbt_tmp)"],
        on_schema_change='fail'
    )
}}

with samples as (
    select * from {{ ref('fct_telemetry') }}
    {% if cutoff %}
    where race_id in ({{ affected_races | join(', ') if affected_races else '-1' }})
      and (race_id, driver_id, lap) in (
          select race_id, driver_id, lap
          from {{ ref('fct_telemetry') }}
          where loaded_at >= {{ cutoff }}
      )
    {% endif %}
)

select
    race_id,
    driver_id,
    lap,
    count(*)::integer as samples,
    max(speed_kph)::number(6, 1) as max_speed_kph,
    avg(throttle_pct)::number(8, 3) as avg_throttle_pct,
    (100.0 * count_if(throttle_pct >= 99) / count(*))::number(8, 3) as full_throttle_pct,
    count_if(brake)::integer as brake_samples,
    max(loaded_at) as last_loaded_at
from samples
group by race_id, driver_id, lap
