select race_id, driver_id, lap
from {{ ref('fct_lap_times') }}
group by 1, 2, 3
having count(*) > 1
