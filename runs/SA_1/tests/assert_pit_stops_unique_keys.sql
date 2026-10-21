select season, constructor_id
from {{ ref('mart_constructor_season_pit_stops') }}
group by 1, 2
having count(*) > 1
