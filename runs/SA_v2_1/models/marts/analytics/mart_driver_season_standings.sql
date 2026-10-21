-- The by-round standings at each season's last completed round.
select
    by_round.season,
    by_round.driver_id,
    by_round.championship_position,
    by_round.points,
    by_round.wins,
    season_status.is_season_complete,
    season_status.last_completed_round
from {{ ref('mart_driver_standings_by_round') }} as by_round
inner join {{ ref('int_season_status') }} as season_status
    on by_round.race_id = season_status.last_completed_race_id
