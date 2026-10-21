{{ config(tags=['reconciliation']) }}
{#
    Reconciliation check, not part of routine runs. It scans every telemetry sample, so run it
    on a schedule (for example weekly) with: dbt test --select tag:reconciliation
    It proves the incremental summary equals a full recompute from fct_telemetry, for every lap.
#}
with recomputed as (

    select
        race_id,
        driver_id,
        lap,
        count(*) as samples,
        max(speed_kph) as max_speed_kph,
        count_if(brake) as brake_samples

    from {{ ref('fct_telemetry') }}
    group by race_id, driver_id, lap

)

select
    recomputed.race_id,
    recomputed.driver_id,
    recomputed.lap

from recomputed
left join {{ ref('mart_lap_telemetry_summary') }} as summary
    on recomputed.race_id = summary.race_id
    and recomputed.driver_id = summary.driver_id
    and recomputed.lap = summary.lap
where summary.race_id is null
    or summary.samples <> recomputed.samples
    or summary.max_speed_kph <> recomputed.max_speed_kph
    or summary.brake_samples <> recomputed.brake_samples
