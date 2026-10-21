-- Pit stops carry no constructor, so attribute via the driver's result in that race.
-- Stops over 60s are red-flag stoppages, not real stops.
with stops as (
    select
        races.season,
        results.constructor_id,
        pit_stops.duration_ms
    from {{ ref('stg_pit_stops') }} as pit_stops
    inner join {{ ref('stg_races') }} as races using (race_id)
    inner join {{ ref('stg_results') }} as results using (race_id, driver_id)
    where pit_stops.duration_ms <= 60000
)

select
    season,
    constructor_id,
    count(*) as pit_stop_count,
    median(duration_ms) / 1000.0 as median_pit_stop_seconds
from stops
group by 1, 2
