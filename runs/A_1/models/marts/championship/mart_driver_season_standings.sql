{#
  Driver championship standings per season, as of the latest completed round
  (the final round for finished seasons) — a slice of
  mart_driver_standings_by_round.

  Built from the official standings rather than by summing race points,
  because summing results does not reproduce official history:
    - before 1991 only a driver's best N results counted (dropped scores), with
      rules that changed almost every season (e.g. 1988: Prost scored 105 gross
      but 87 counted; Senna champion on 90);
    - since 2021 sprint points count but live outside Grand Prix results;
    - 1997: Schumacher was excluded from the championship.
  The reconciliation test assert_standings_reconcile_to_results proves the
  standings equal GP + sprint points for every season without dropped scores.
#}

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
    seasons.latest_completed_round                  as as_of_round,
    seasons.latest_completed_race_id                as as_of_race_id,
    seasons.is_complete                             as is_season_complete,
    standings_by_round.is_excluded_from_championship
from seasons
inner join standings_by_round
    on seasons.latest_completed_race_id = standings_by_round.race_id
