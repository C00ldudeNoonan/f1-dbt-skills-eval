-- Official driver standings after every round in which the driver appears in the
-- published snapshot (which carries dropped scores and sprint points).
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.position as championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_ergast__driver_standings') }} as standings
inner join {{ ref('stg_ergast__races') }} as races on standings.race_id = races.race_id
