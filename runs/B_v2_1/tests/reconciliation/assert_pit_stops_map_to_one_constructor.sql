-- The pit stop mart assigns each stop to the driver's constructor for that race.
-- That only works if no driver with pit stops has two constructors in one race.
select entries.race_id, entries.driver_id, count(*) as constructors
from {{ ref('int_race_driver_constructors') }} as entries
where exists (
    select 1 from {{ ref('stg_ergast__pit_stops') }} as stops
    where stops.race_id = entries.race_id and stops.driver_id = entries.driver_id
)
group by 1, 2
having count(*) > 1
