-- Official championship standings after each round, one row per driver per round they
-- appear in the source standings table.
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.position as championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_driver_standings') }} as standings
inner join {{ ref('stg_races') }} as races using (race_id)
