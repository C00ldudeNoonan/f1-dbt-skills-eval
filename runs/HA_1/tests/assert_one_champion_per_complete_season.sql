-- Every complete season has exactly one driver in championship position 1.
select
    season,
    count(*) as champions
from {{ ref('mart_driver_season_standings') }}
where is_season_complete
    and championship_position = 1
group by season
having count(*) <> 1
