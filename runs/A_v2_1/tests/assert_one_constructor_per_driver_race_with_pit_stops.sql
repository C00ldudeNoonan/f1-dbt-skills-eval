-- mart_constructor_season_pit_stops attributes stops to a constructor through the
-- driver's race result. That is only safe while a driver has a single constructor
-- per race wherever pit stop data exists.
select
    results.race_id,
    results.driver_id,
    count(distinct results.constructor_id) as constructors
from {{ ref('fct_results') }} as results
where exists (
    select 1
    from {{ ref('stg_ergast__pit_stops') }} as pit_stops
    where pit_stops.race_id = results.race_id
        and pit_stops.driver_id = results.driver_id
)
group by 1, 2
having count(distinct results.constructor_id) > 1
