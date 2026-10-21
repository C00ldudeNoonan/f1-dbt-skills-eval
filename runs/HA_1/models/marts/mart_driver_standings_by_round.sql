-- Official driver championship standings after every round, one row per driver per round they appear in.
-- Built from the standings snapshots, so historical points (including drop-score rules) match the published tables.

select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races
    on standings.race_id = races.race_id
