-- Grain: one row per driver per season, as of the latest completed round.
select
    by_round.season,
    by_round.driver_id,
    by_round.championship_position,
    by_round.points,
    by_round.wins
from {{ ref('mart_driver_standings_by_round') }} as by_round
inner join {{ ref('int_season_status') }} as status
    on by_round.race_id = status.last_completed_race_id
