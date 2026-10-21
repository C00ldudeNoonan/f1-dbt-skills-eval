-- Every completed round (a race with Grand Prix results) must have official
-- standings, with exactly one leader.

select
    races.race_id,
    races.season,
    races.round,
    count(standings.driver_id) as n_drivers,
    count_if(standings.championship_position = 1) as n_leaders
from {{ ref('stg_ergast__races') }} as races
inner join (select distinct race_id from {{ ref('stg_ergast__results') }}) as completed
    on races.race_id = completed.race_id
left join {{ ref('mart_driver_standings_by_round') }} as standings
    on races.race_id = standings.race_id
group by 1, 2, 3
having count(standings.driver_id) = 0
    or count_if(standings.championship_position = 1) <> 1
