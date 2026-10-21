-- Standings as of each season's latest round that has results, taken from the official
-- per-round standings (see mart_driver_standings_by_round).
select
    by_round.season,
    by_round.driver_id,
    by_round.championship_position,
    by_round.points,
    by_round.wins
from {{ ref('mart_driver_standings_by_round') }} as by_round
inner join {{ ref('int_season_status') }} as seasons
    on seasons.season = by_round.season
    and seasons.last_completed_round = by_round.round
