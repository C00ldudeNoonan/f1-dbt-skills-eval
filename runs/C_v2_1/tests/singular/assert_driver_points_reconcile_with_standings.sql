-- Cross-source reconciliation: since 1991 (no dropped scores), a driver's
-- cumulative Grand Prix plus sprint points from fct_session_results must
-- equal the official standings after every round.

with round_points as (
    select
        season,
        round,
        driver_id,
        sum(points) as points
    from {{ ref('fct_session_results') }}
    where season >= 1991
    group by season, round, driver_id
),

standings as (
    select
        season,
        round,
        driver_id,
        points
    from {{ ref('mart_driver_standings_by_round') }}
    where season >= 1991
),

cumulative as (
    select
        standings.season,
        standings.round,
        standings.driver_id,
        standings.points as official_points,
        coalesce(sum(round_points.points), 0) as fact_points
    from standings
    left join round_points
        on standings.season = round_points.season
        and standings.driver_id = round_points.driver_id
        and round_points.round <= standings.round
    group by standings.season, standings.round, standings.driver_id, standings.points
)

select *
from cumulative
where official_points <> fact_points
