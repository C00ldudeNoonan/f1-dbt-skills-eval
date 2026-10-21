-- Pit stops carry no constructor, so attribute each stop via the driver's result in that race.
-- Stops over 60s are red-flag stoppages rather than real stops and are excluded.
{% set max_pit_stop_ms = 60000 %}

with stops as (

    select * from {{ ref('stg_f1__pit_stops') }}
    where duration_ms <= {{ max_pit_stop_ms }}

),

driver_race_constructor as (

    select distinct race_id, driver_id, constructor_id, season
    from {{ ref('fct_results') }}

),

constructors as (

    select * from {{ ref('stg_f1__constructors') }}

)

select
    driver_race_constructor.season,
    driver_race_constructor.constructor_id,
    constructors.constructor_name,
    count(*)                                        as pit_stop_count,
    median(stops.duration_ms) / 1000                as median_pit_stop_seconds
from stops
inner join driver_race_constructor
    on stops.race_id = driver_race_constructor.race_id
    and stops.driver_id = driver_race_constructor.driver_id
inner join constructors
    on driver_race_constructor.constructor_id = constructors.constructor_id
group by 1, 2, 3
