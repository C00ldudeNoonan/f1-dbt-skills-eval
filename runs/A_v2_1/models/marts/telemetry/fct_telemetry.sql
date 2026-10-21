{#-
    One row per telemetry sample.

    Incremental by arrival, not by race: each run reads only raw rows whose
    loaded_at is newer than this table's high-water mark (minus a lookback),
    so a sample that lands weeks after its race is picked up on the next run
    while the routine scan stays proportional to what arrived. Rows are merged
    on the sample key, so a re-delivered sample replaces the earlier copy and
    re-reading the lookback window never duplicates anything.

    Clustered by race_id so the lap summary (and analysts) can prune to the
    races they need.
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap', 'sample_index'],
        cluster_by=['race_id'],
        on_schema_change='append_new_columns'
    )
}}

with new_samples as (

    select *
    from {{ ref('stg_telemetry__car_telemetry') }}
    {% if is_incremental() %}
    where loaded_at > {{ telemetry_watermark(this, 'loaded_at') }}
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
    loaded_at
from new_samples
-- If the feed re-sends a sample, keep the most recently loaded copy.
qualify row_number() over (
    partition by race_id, driver_id, lap, sample_index
    order by loaded_at desc
) = 1
