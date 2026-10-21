-- Every season with a completed round has exactly one standings round
-- flagged as latest, and the season mart has the same driver count as that round.
with latest as (
    select season, count(*) as drivers, count(distinct round) as rounds
    from {{ ref('mart_driver_standings_by_round') }}
    where is_latest_completed_round
    group by season
),

season_mart as (
    select season, count(*) as drivers
    from {{ ref('mart_driver_season_standings') }}
    group by season
)

select latest.season, latest.drivers, latest.rounds, season_mart.drivers as season_mart_drivers
from latest
full outer join season_mart
    on latest.season = season_mart.season
where latest.rounds <> 1
    or latest.drivers is distinct from season_mart.drivers
