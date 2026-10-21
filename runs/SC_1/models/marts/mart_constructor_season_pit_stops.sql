-- Stops over 60s are red-flag stoppages, not real stops, and are excluded from both
-- the count and the median.
with pit_stops as (

    select * from {{ ref('stg_f1__pit_stops') }}
    where duration_ms <= 60000

),

driver_race_constructor as (

    select race_id, driver_id, constructor_id, season
    from {{ ref('fct_results') }}

)

select
    driver_race_constructor.season,
    driver_race_constructor.constructor_id,
    count(*) as pit_stop_count,
    median(pit_stops.duration_ms) / 1000 as median_pit_stop_seconds
from pit_stops
inner join driver_race_constructor
    on pit_stops.race_id = driver_race_constructor.race_id
    and pit_stops.driver_id = driver_race_constructor.driver_id
group by driver_race_constructor.season, driver_race_constructor.constructor_id
