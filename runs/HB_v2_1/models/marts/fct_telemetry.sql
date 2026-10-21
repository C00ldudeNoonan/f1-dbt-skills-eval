{#
    One row per car telemetry sample, keyed by race, driver, lap and sample index.

    Incremental on _LOADED_AT (loaded_at), not RECORDED_AT. A late sample, weeks after its race,
    lands with a fresh loaded_at, so a routine run reads only the newest landings. Old partitions
    are never scanned. Each run reads from the newest loaded_at minus a lookback. The lookback
    (telemetry_lookback_hours) absorbs out-of-order commits at the edge of a load.

    Samples merge on the key, so a corrected sample updates its row. The table is clustered on
    race and driver, the columns the merge and the lap summary filter on.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['race_id', 'driver_id', 'lap', 'sample_index'],
    cluster_by=['race_id', 'driver_id'],
    on_schema_change='fail'
) }}

with telemetry as (

    select *
    from {{ ref('stg_f1__car_telemetry') }}

    {% if is_incremental() %}
    where loaded_at > (
        select coalesce(
            dateadd(hour, -{{ var('telemetry_lookback_hours') }}, max(loaded_at)),
            '1900-01-01'::timestamp_ntz
        )
        from {{ this }}
    )
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

from telemetry
