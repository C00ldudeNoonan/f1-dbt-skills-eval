{#
    Official driver championship standings, one row per driver per season, taken from the
    standings after the latest completed round. Derived from mart_driver_standings_by_round.

    The source snapshot is the official table, so the numbers match published
    championships. Summing Grand Prix points would not: it ignores dropped scores before
    1991 and sprint points from 2021.

    For a complete season this is the final round. For an incomplete season (2024, rounds
    23 and 24 have no results) it is the last completed round. is_season_complete says which
    case applies.
#}
with completion as (

    select * from {{ ref('int_season_completion') }}

),

standings as (

    select * from {{ ref('mart_driver_standings_by_round') }}

)

select
    completion.season,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins,
    completion.latest_completed_round as round,
    standings.race_id as as_of_race_id,
    completion.is_season_complete,
    standings.championship_position = 1 as is_champion

from completion
inner join standings
    on completion.latest_completed_race_id = standings.race_id
