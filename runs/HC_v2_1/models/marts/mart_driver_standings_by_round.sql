{#
    One row per driver per round they appear in the official driver standings. This is the base for
    season standings and any analysis of the championship as it stood after each round.

    championship_position is null when the official table leaves the driver unranked (1997 Schumacher, POSITIONTEXT D).
#}
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    case
        when regexp_like(standings.position_text, '^[0-9]+$') then standings.position
    end as championship_position,
    standings.points,
    standings.wins
from {{ ref('stg_f1__driver_standings') }} as standings
inner join {{ ref('stg_f1__races') }} as races
    on standings.race_id = races.race_id
