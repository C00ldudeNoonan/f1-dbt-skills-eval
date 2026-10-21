select
    race_id,
    driver_id,
    count(*) as row_count
from {{ ref('mart_driver_standings_by_round') }}
group by race_id, driver_id
having count(*) > 1
