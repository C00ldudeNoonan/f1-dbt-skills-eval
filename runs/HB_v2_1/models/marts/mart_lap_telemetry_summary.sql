{#
    One row per driver per lap, summarising the car telemetry samples for that lap.
    full_throttle_pct is the share of samples at throttle 99 or above, as a percentage.

    Incremental and merged on (race_id, driver_id, lap). A run finds the laps that received a
    sample since the last run, and recomputes only those laps from fct_telemetry. A late sample
    for a lap from last month therefore corrects that lap's summary, and nothing else is rebuilt.
    last_loaded_at is the newest sample landing for the lap. The next run's window starts from it.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['race_id', 'driver_id', 'lap'],
    on_schema_change='fail'
) }}

with samples as (

    select telemetry.*
    from {{ ref('fct_telemetry') }} as telemetry

    {% if is_incremental() %}
    inner join (
        select distinct race_id, driver_id, lap
        from {{ ref('fct_telemetry') }}
        where loaded_at > (
            select coalesce(
                dateadd(hour, -{{ var('telemetry_lookback_hours') }}, max(last_loaded_at)),
                '1900-01-01'::timestamp_ntz
            )
            from {{ this }}
        )
    ) as affected_laps
        on telemetry.race_id = affected_laps.race_id
        and telemetry.driver_id = affected_laps.driver_id
        and telemetry.lap = affected_laps.lap
    {% endif %}

)

select
    race_id,
    driver_id,
    lap,
    count(*) as samples,
    max(speed_kph) as max_speed_kph,
    avg(throttle_pct) as avg_throttle_pct,
    100.0 * count_if(throttle_pct >= 99) / count(*) as full_throttle_pct,
    count_if(brake) as brake_samples,
    max(loaded_at) as last_loaded_at

from samples
group by race_id, driver_id, lap
