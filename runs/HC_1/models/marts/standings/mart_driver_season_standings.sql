-- Official driver championship standings, one row per driver per season, as of the latest
-- completed round of that season. Derived from the by-round standings so the two stay consistent.
with standings_by_round as (

    select * from {{ ref('mart_driver_standings_by_round') }}

),

completeness as (

    select * from {{ ref('int_season_completeness') }}

)

select
    standings_by_round.season,
    standings_by_round.driver_id,
    standings_by_round.championship_position,
    standings_by_round.points,
    standings_by_round.wins,
    completeness.latest_completed_round,
    completeness.is_season_complete,
    -- A title only counts once the season is complete.
    standings_by_round.championship_position = 1 and completeness.is_season_complete as is_champion

from standings_by_round
inner join completeness
    on standings_by_round.season = completeness.season
    and standings_by_round.round = completeness.latest_completed_round
