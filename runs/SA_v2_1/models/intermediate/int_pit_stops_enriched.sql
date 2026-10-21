-- One row per pit stop with its race, circuit and constructor. `duration_s` is the pit LANE time the feed
-- records (pit entry to pit exit), not the stationary time of the tyre change. `is_included` is false for
-- stops over 60 s: red-flag stoppages, repairs and penalty serves, not routine stops.
with driver_race_constructor as (

    select distinct race_id, driver_id, constructor_id
    from {{ ref('fct_results') }}

)

select
    pit_stops.race_id,
    races.season,
    races.round,
    races.circuit_id,
    pit_stops.driver_id,
    driver_race_constructor.constructor_id,
    pit_stops.stop_number,
    pit_stops.lap,
    pit_stops.duration_ms / 1000.0 as duration_s,
    pit_stops.duration_ms <= 60000 as is_included
from {{ ref('stg_ergast__pit_stops') }} as pit_stops
inner join {{ ref('stg_ergast__races') }} as races on pit_stops.race_id = races.race_id
inner join driver_race_constructor
    on pit_stops.race_id = driver_race_constructor.race_id
    and pit_stops.driver_id = driver_race_constructor.driver_id
