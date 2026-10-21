-- Official championship table after every round, one row per driver per round they appear in.
-- Source of truth for how the championship evolved; the season mart is derived from this.
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races on standings.race_id = races.race_id
