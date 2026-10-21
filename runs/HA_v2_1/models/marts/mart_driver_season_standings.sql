{#
    Grain: one row per driver per season, as of the latest completed round.
    Derived from mart_driver_standings_by_round at the season's latest completed round
    (see int_season_completeness). For a season that is not complete, this shows
    standings as of the last round that has results.
#}
select
    standings.season,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins,
    completeness.latest_completed_round,
    completeness.is_season_complete,
    standings.race_id as latest_completed_race_id
from {{ ref('mart_driver_standings_by_round') }} as standings
inner join {{ ref('int_season_completeness') }} as completeness
    on standings.season = completeness.season
    and standings.round = completeness.latest_completed_round
