-- Every completed season must have exactly one P1 in the standings mart.
select standings.season, count(*) as n_champions
from {{ ref('mart_driver_season_standings') }} as standings
inner join {{ ref('int_season_completeness') }} as seasons using (season)
where seasons.is_complete
group by standings.season
having count_if(standings.championship_position = 1) <> 1
