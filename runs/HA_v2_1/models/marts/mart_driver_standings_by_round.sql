{#
    Grain: one row per driver per round they appear in the official standings snapshot.
    Values are the snapshot as it stood after that round (drop scores pre-1991 and sprint
    points from 2021 are already in the official figures). mart_driver_season_standings
    is derived from this model.
#}
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.position_number as championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races
    on standings.race_id = races.race_id
