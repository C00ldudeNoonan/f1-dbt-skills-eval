{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap', 'sample_index'],
        cluster_by=['race_id']
    )
}}

-- One row per telemetry sample. Incremental on the *load* time (`loaded_at`), not the race: samples that
-- arrive weeks after a race carry a new loaded_at, so the very next run picks them up and merges them into
-- the right race by key. A run reads only raw rows loaded since the newest row we hold, minus a small
-- lookback (var `telemetry_lookback_hours`) for loads that were still committing. Rows we already hold
-- unchanged are dropped before the merge, so a run with nothing new writes nothing. A re-delivered sample
-- replaces the old copy (latest loaded_at wins, also inside one batch).
-- `ingested_at` is our own write time; downstream incrementals use it as their watermark.
-- Escape hatch: --vars '{telemetry_reload_races: [1142]}' re-reads those races completely (for rows that
-- landed with an old loaded_at). assert_telemetry_row_counts_match_raw flags that situation.
{% set reload_races = var('telemetry_reload_races', []) %}

with batch as (

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
    from {{ ref('stg_telemetry__car_telemetry') }}

    {% if is_incremental() %}
    where loaded_at >= (
        select dateadd(hour, -{{ var('telemetry_lookback_hours') }}, max(loaded_at)) from {{ this }}
    )
    {% if reload_races %}
        or race_id in ({{ reload_races | join(', ') }})
    {% endif %}
    {% endif %}

    qualify row_number() over (
        partition by race_id, driver_id, lap, sample_index
        order by loaded_at desc
    ) = 1

)

select
    batch.*,
    current_timestamp()::timestamp_ntz as ingested_at
from batch

{% if is_incremental() %}
where not exists (
    select 1
    from {{ this }} as existing
    where existing.race_id = batch.race_id
        and existing.driver_id = batch.driver_id
        and existing.lap = batch.lap
        and existing.sample_index = batch.sample_index
        and existing.loaded_at = batch.loaded_at
        and existing.loaded_at >= (
            select dateadd(hour, -{{ var('telemetry_lookback_hours') }}, max(loaded_at)) from {{ this }}
        )
        {% if reload_races %}
        and existing.race_id not in ({{ reload_races | join(', ') }})
        {% endif %}
)
{% endif %}
