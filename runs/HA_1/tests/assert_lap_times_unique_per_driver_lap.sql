-- Each driver has at most one row per lap per race.
select
    race_id,
    driver_id,
    lap
from {{ ref('fct_lap_times') }}
group by race_id, driver_id, lap
having count(*) > 1
