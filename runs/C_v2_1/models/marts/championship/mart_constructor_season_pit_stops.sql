with pit_stops as (
    select * from {{ ref('stg_f1__pit_stops') }}
),

results as (
    select * from {{ ref('fct_results') }}
),

stops_with_constructor as (
    -- Pit stop data starts in 2011, when every driver has exactly one result
    -- per race, so this join cannot fan out (tested on the mart).
    select
        results.season,
        results.constructor_id,
        pit_stops.duration_ms
    from pit_stops
    inner join results
        on pit_stops.race_id = results.race_id
        and pit_stops.driver_id = results.driver_id
    -- Stops over 60 seconds are red-flag stoppages, not pit work.
    where pit_stops.duration_ms <= 60000
)

select
    season,
    constructor_id,
    count(*) as pit_stop_count,
    (median(duration_ms) / 1000)::number(10, 4) as median_pit_stop_seconds
from stops_with_constructor
group by season, constructor_id
