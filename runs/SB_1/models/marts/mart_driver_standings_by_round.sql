-- Official standings after each round. Source standings carry only race_id; season and round
-- come from the calendar.
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.position      as championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races
    on standings.race_id = races.race_id
