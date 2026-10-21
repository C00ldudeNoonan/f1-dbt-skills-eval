-- From 1991 every result counts toward the championship, so a driver's
-- standings points must equal their Grand Prix + sprint points up to the
-- as-of round. A mismatch means the standings snapshot is from the wrong round
-- or results are missing/duplicated. Earlier seasons used dropped scores.
with race_points as (
    select season, driver_id, sum(points) as points
    from {{ ref('fct_results') }}
    group by season, driver_id
),

sprint_points as (
    select races.season, sprints.driver_id, sum(sprints.points) as points
    from {{ ref('stg_ergast__sprint_results') }} as sprints
    inner join {{ ref('stg_ergast__races') }} as races
        on sprints.race_id = races.race_id
    group by races.season, sprints.driver_id
)

select
    standings.season,
    standings.driver_id,
    standings.points as standings_points,
    coalesce(race_points.points, 0) + coalesce(sprint_points.points, 0) as results_points
from {{ ref('mart_driver_season_standings') }} as standings
left join race_points
    on standings.season = race_points.season and standings.driver_id = race_points.driver_id
left join sprint_points
    on standings.season = sprint_points.season and standings.driver_id = sprint_points.driver_id
where standings.season >= 1991
  and standings.points != coalesce(race_points.points, 0) + coalesce(sprint_points.points, 0)
