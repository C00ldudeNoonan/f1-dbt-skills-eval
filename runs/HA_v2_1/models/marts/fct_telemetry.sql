{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='sample_id',
        cluster_by=['race_id', 'driver_id', 'lap']
    )
}}
{#
    Grain: one row per telemetry sample (sample_id = race, driver, lap, sample_index).

    Routine runs read only raw rows loaded since the last run: the predicate is on _LOADED_AT, the
    load time, so the warehouse prunes old micro-partitions instead of scanning all of CAR_TELEMETRY.
    Late samples (recorded weeks ago, loaded today) carry a recent _loaded_at, so they are picked up.
    A one-day lookback re-reads the most recent day so a load committed just after a run is not
    missed. The merge is keyed on sample_id, so re-reading rows never duplicates them.
#}
select
    race_id || '|' || driver_id || '|' || lap || '|' || sample_index as sample_id,
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
    _loaded_at
from {{ ref('stg_f1__car_telemetry') }}
{% if is_incremental() %}
where _loaded_at > (
    select dateadd(day, -1, max(_loaded_at)) from {{ this }}
)
{% endif %}
