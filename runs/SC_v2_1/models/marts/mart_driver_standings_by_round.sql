-- Official standings after each round: the raw standings snapshot, one row per driver
-- per round they appear in.
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races on races.race_id = standings.race_id
