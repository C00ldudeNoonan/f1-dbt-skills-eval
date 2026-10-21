-- Driver championship standings per season as of the latest completed round:
-- the by-round standings filtered to each season's latest round with results.
with seasons as (

    select * from {{ ref('int_seasons__completion') }}

),

standings_by_round as (

    select * from {{ ref('mart_driver_standings_by_round') }}

)

select
    seasons.season,
    standings_by_round.driver_id,
    standings_by_round.championship_position,
    standings_by_round.position_text,
    standings_by_round.points,
    standings_by_round.wins,
    seasons.latest_completed_round as as_of_round,
    seasons.latest_completed_race_id as as_of_race_id,
    seasons.is_season_complete
from seasons
inner join standings_by_round
    on seasons.latest_completed_race_id = standings_by_round.race_id
