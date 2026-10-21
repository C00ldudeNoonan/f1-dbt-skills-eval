-- Official end-of-season standings: the by-round standings at the latest completed
-- round of each season. For an unfinished season this is the standings so far.
select
    by_round.season,
    by_round.driver_id,
    by_round.championship_position,
    by_round.points,
    by_round.wins,
    by_round.round as as_of_round,
    season_status.is_season_complete
from {{ ref('mart_driver_standings_by_round') }} as by_round
inner join {{ ref('int_f1__season_status') }} as season_status
    on season_status.season = by_round.season
    and season_status.latest_completed_round = by_round.round
