select season, driver_id, count(*) as row_count
from {{ ref('mart_driver_season_standings') }}
group by season, driver_id
having count(*) > 1
