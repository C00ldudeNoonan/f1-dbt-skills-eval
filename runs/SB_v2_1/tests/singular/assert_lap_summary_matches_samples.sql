-- Recently refreshed laps in the summary must agree with their samples in fct_telemetry (guards the
-- incremental re-aggregation, e.g. a late sample that updated fct_telemetry but not the summary).
with recent as (
    select race_id, driver_id, lap, samples, last_loaded_at
    from {{ ref('mart_lap_telemetry_summary') }}
    where last_loaded_at >= dateadd(day, -3, (select max(last_loaded_at) from {{ ref('mart_lap_telemetry_summary') }}))
)
select recent.race_id, recent.driver_id, recent.lap, recent.samples, count(*) as actual_samples
from recent
inner join {{ ref('fct_telemetry') }} as t
    on t.race_id = recent.race_id and t.driver_id = recent.driver_id and t.lap = recent.lap
where t.race_id in (select distinct race_id from recent)
group by all
having count(*) <> max(recent.samples) or max(t.loaded_at) <> max(recent.last_loaded_at)
