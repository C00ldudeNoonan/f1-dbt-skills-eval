-- Final standings per season: the by-round standings at the latest round with results.
-- (Official points, not recomputed from results; see mart_driver_standings_by_round.)
select
    by_round.season,
    by_round.driver_id,
    by_round.championship_position,
    by_round.points,
    by_round.wins
from {{ ref('mart_driver_standings_by_round') }} as by_round
inner join {{ ref('int_season_completeness') }} as seasons
    on by_round.race_id = seasons.last_completed_race_id
