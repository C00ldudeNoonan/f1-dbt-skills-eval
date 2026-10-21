select season, round, driver_id
from {{ ref('mart_driver_standings_by_round') }}
group by 1, 2, 3
having count(*) > 1
