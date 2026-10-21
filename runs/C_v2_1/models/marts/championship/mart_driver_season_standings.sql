-- Official drivers' championship standings per season, as of the latest
-- completed round: the latest-round slice of mart_driver_standings_by_round.

select
    season,
    driver_id,
    championship_position,
    position_text,
    points,
    wins,
    round as as_of_round,
    race_id as as_of_race_id,
    is_season_complete
from {{ ref('mart_driver_standings_by_round') }}
where is_latest_completed_round
