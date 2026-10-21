{#-
  Official standings per season as of the latest completed round: the
  by-round standings filtered to that round. We use the published snapshot
  rather than summing race points so drop scores, shared drives and sprint
  points match the official tables.
-#}
select
    by_round.season,
    by_round.driver_id,
    by_round.championship_position,
    by_round.points,
    by_round.wins,
    by_round.is_excluded,
    seasons.latest_completed_round      as as_of_round,
    seasons.latest_completed_race_id    as as_of_race_id,
    seasons.is_complete                 as is_season_complete
from {{ ref('mart_driver_standings_by_round') }} as by_round
inner join {{ ref('int_seasons') }} as seasons
    on by_round.race_id = seasons.latest_completed_race_id
