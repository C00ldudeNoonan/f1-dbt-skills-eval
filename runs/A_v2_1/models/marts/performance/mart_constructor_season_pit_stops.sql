-- Pit stop volume and median stationary-plus-lane time per constructor and season.
-- Stops over pit_stop_max_seconds are red-flag stoppages and are excluded.
with pit_stops as (

    select * from {{ ref('stg_ergast__pit_stops') }}

),

-- Pit stops carry no constructor, so take it from the driver's result in that
-- race. A driver has at most one result per race in the pit stop era (tested).
race_driver_constructor as (

    select distinct race_id, driver_id, constructor_id, season
    from {{ ref('fct_results') }}

)

select
    race_driver_constructor.season,
    race_driver_constructor.constructor_id,
    count(*) as pit_stop_count,
    median(pit_stops.duration_ms) / 1000.0 as median_pit_stop_seconds
from pit_stops
inner join race_driver_constructor
    on pit_stops.race_id = race_driver_constructor.race_id
    and pit_stops.driver_id = race_driver_constructor.driver_id
where pit_stops.duration_ms <= {{ var('pit_stop_max_seconds') }} * 1000
group by 1, 2
