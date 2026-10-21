-- Grain: one row per driver per round in the official standings snapshot.
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.position as championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races on races.race_id = standings.race_id
