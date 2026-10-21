-- Grain: one row per telemetry sample (race_id, driver_id, lap, sample_index). ~20M rows and growing.
--
-- Incremental on ingestion time. Each run reads only raw rows with _loaded_at at/after the target's high-water
-- mark (minus a 15 minute lookback), so a routine run touches the newest micro-partitions only, and merges them by
-- key. Late samples (old race, new _loaded_at) are therefore picked up automatically; a re-sent sample with the
-- same key replaces the earlier one (the newest load wins). The merge target is pruned to the races present in the batch (incremental_predicates on the batch table).
-- A full refresh reads the whole raw table once and sorts by loaded_at, which keeps the table naturally
-- clustered by load time (and by race, since races load in order) so these filters prune well.
{% set cutoff = telemetry_cutoff('loaded_at') %}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap', 'sample_index'],
        incremental_predicates=["DBT_INTERNAL_DEST.race_id in (select distinct race_id from " ~ this ~ "__dbt_tmp)"],
        on_schema_change='fail'
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
{% if cutoff %}
where loaded_at >= {{ cutoff }}
{% endif %}
qualify row_number() over (
    partition by race_id, driver_id, lap, sample_index
    order by loaded_at desc
) = 1
{% if not is_incremental() %}
order by loaded_at, race_id, driver_id, lap, sample_index
{% endif %}
