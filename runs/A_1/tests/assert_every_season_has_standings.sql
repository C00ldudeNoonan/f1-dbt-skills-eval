-- Every season with at least one completed round must produce standings,
-- with exactly one leader.

select
    seasons.season,
    count(standings.driver_id) as n_drivers,
    count_if(standings.championship_position = 1) as n_leaders
from {{ ref('int_seasons__completion') }} as seasons
left join {{ ref('mart_driver_season_standings') }} as standings
    on seasons.season = standings.season
where seasons.completed_rounds > 0
group by seasons.season
having count(standings.driver_id) = 0
    or count_if(standings.championship_position = 1) <> 1
