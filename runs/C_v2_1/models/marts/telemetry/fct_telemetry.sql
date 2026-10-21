{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

-- One row per telemetry sample. Incremental by whole race: each run finds the
-- races with samples loaded since the last run (see
-- telemetry_races_to_process) and rebuilds only those. Late samples, even
-- weeks after the race, land with a new _LOADED_AT, so their race is
-- rebuilt in full. Duplicates of a sample keep the latest load. A routine run
-- reads only the raw micro-partitions for those races, never the whole table.

{% set races = telemetry_races_to_process(
    this, 'source_loaded_at',
    ref('stg_telemetry__car_samples'), 'source_loaded_at', 'race_id'
) if is_incremental() else none %}

with samples as (
    select *
    from {{ ref('stg_telemetry__car_samples') }}
    {% if races is not none %}
    where {{ race_filter('race_id', races) }}
    {% endif %}
),

deduplicated as (
    select *
    from samples
    qualify row_number() over (
        partition by race_id, driver_id, lap, sample_index
        order by source_loaded_at desc
    ) = 1
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
    source_loaded_at,
    sysdate() as processed_at
from deduplicated
-- Writing rows in race order keeps each race in its own micro-partitions, so
-- the incremental delete of one race rewrites only that race's partitions
-- instead of the whole table. It's free, unlike automatic clustering.
order by race_id, driver_id, lap, sample_index
