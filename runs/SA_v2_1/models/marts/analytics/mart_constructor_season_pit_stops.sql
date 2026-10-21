-- Stops over 60 seconds are red-flag stoppages, not real pit work, and are excluded.
-- The constructor is the one the driver raced for in that Grand Prix.
with driver_race_constructor as (

    select distinct race_id, driver_id, constructor_id
    from {{ ref('fct_results') }}

),

stops as (

    select
        races.season,
        driver_race_constructor.constructor_id,
        pit_stops.duration_ms
    from {{ ref('stg_ergast__pit_stops') }} as pit_stops
    inner join driver_race_constructor
        on pit_stops.race_id = driver_race_constructor.race_id
        and pit_stops.driver_id = driver_race_constructor.driver_id
    inner join {{ ref('stg_ergast__races') }} as races on pit_stops.race_id = races.race_id
    where pit_stops.duration_ms <= 60000

)

select
    season,
    constructor_id,
    count(*) as pit_stop_count,
    median(duration_ms) / 1000.0 as median_pit_stop_seconds
from stops
group by season, constructor_id
