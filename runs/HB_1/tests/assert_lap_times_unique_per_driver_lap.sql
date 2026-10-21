select
    race_id,
    driver_id,
    lap,
    count(*) as row_count
from {{ ref('fct_lap_times') }}
group by race_id, driver_id, lap
having count(*) > 1
