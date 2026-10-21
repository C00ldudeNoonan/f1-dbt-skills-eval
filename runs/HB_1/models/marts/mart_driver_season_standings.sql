-- One row per driver per season, as of the latest round that has results.
-- Points, position and wins are the official championship figures from the source standings table.
-- They are not recomputed from results, because the official tables include sprint points (2021+)
-- and dropped scores (early seasons).
-- Derived from mart_driver_standings_by_round, filtered to each season's latest completed round.
with standings_by_round as (

    select * from {{ ref('mart_driver_standings_by_round') }}

),

seasons as (

    select * from {{ ref('int_seasons') }}

)

select
    standings_by_round.season,
    standings_by_round.round,
    standings_by_round.driver_id,
    standings_by_round.championship_position,
    standings_by_round.points,
    standings_by_round.wins,
    seasons.is_season_complete
from standings_by_round
inner join seasons
    on seasons.latest_completed_race_id = standings_by_round.race_id
