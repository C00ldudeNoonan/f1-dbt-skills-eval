-- Each season in the standings mart has exactly one championship leader.
select season, count_if(championship_position = 1) as leaders
from {{ ref('mart_driver_season_standings') }}
group by season
having count_if(championship_position = 1) <> 1
