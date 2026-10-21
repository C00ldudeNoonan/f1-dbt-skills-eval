select
    season,
    count(*) as champions

from {{ ref('mart_driver_season_standings') }}
where is_champion
    and is_season_complete
group by season
having count(*) <> 1
