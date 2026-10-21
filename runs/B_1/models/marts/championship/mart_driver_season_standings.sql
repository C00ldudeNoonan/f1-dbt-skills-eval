{#
    Official drivers' championship standings, one row per driver per season,
    as of the season's latest completed round: the by-round standings filtered
    to that round. For the current (incomplete) season this is the live
    table, and is_season_complete tells you which case you have.
#}

with standings_by_round as (
    select * from {{ ref('mart_driver_standings_by_round') }}
),

seasons as (
    select * from {{ ref('int_season_calendar_progress') }}
)

select
    seasons.season,
    standings_by_round.driver_id,
    standings_by_round.driver_ref,
    standings_by_round.full_name,
    standings_by_round.championship_position,
    standings_by_round.points,
    standings_by_round.wins,
    seasons.latest_completed_round      as as_of_round,
    seasons.latest_completed_race_id    as as_of_race_id,
    seasons.is_season_complete,
    standings_by_round.is_excluded_from_championship
from seasons
inner join standings_by_round
    on seasons.latest_completed_race_id = standings_by_round.race_id
