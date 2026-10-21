-- From 1991 onward every result counts (no dropped scores), so official
-- standings points must equal Grand Prix + sprint points summed from results,
-- and wins must equal GP wins. Catches broken joins, the wrong as-of round,
-- or sprint points going missing.

with season_rounds as (
    select season, latest_completed_round
    from {{ ref('int_seasons__completion') }}
),

races as (
    select r.race_id, r.season
    from {{ ref('stg_ergast__races') }} as r
    inner join season_rounds as s
        on r.season = s.season
       and r.round <= s.latest_completed_round
    where r.season >= 1991
),

all_points as (
    select race_id, driver_id, points, iff(finish_position = 1, 1, 0) as win
    from {{ ref('stg_ergast__results') }}
    union all
    select race_id, driver_id, points, 0 as win
    from {{ ref('stg_ergast__sprint_results') }}
),

computed as (
    select races.season, all_points.driver_id, sum(points) as points, sum(win) as wins
    from all_points
    inner join races on all_points.race_id = races.race_id
    group by 1, 2
),

official as (
    select season, driver_id, points, wins
    from {{ ref('mart_driver_season_standings') }}
    where season >= 1991
)

select
    coalesce(official.season, computed.season) as season,
    coalesce(official.driver_id, computed.driver_id) as driver_id,
    official.points as official_points,
    computed.points as computed_points,
    official.wins as official_wins,
    computed.wins as computed_wins
from official
full outer join computed
    on official.season = computed.season
   and official.driver_id = computed.driver_id
where
    -- a points scorer missing from the official table
    (official.driver_id is null and computed.points > 0)
    -- or an official row that disagrees with the results
    or (official.driver_id is not null
        and (computed.driver_id is null
             or official.points <> computed.points
             or official.wins <> computed.wins))
