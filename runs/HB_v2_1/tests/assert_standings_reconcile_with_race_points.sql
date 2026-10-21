{#
    The change in a driver's championship points from one round to the next must equal the
    points that driver scored in that round (Grand Prix plus sprint). This holds from 1991,
    when dropped scores ended. It catches a standings feed that disagrees with the results.
#}
with standings as (

    select
        races.season,
        races.round,
        standings.race_id,
        standings.driver_id,
        standings.points,
        standings.points - coalesce(lag(standings.points) over (
            partition by races.season, standings.driver_id order by races.round
        ), 0) as points_change

    from {{ ref('stg_f1__driver_standings') }} as standings
    inner join {{ ref('stg_f1__races') }} as races
        on standings.race_id = races.race_id
    where races.season >= 1991

),

race_points as (

    select race_id, driver_id, sum(points) as points
    from {{ ref('stg_f1__results') }}
    group by race_id, driver_id

),

sprint_points as (

    select race_id, driver_id, sum(points) as points
    from {{ ref('stg_f1__sprint_results') }}
    group by race_id, driver_id

)

select
    standings.season,
    standings.round,
    standings.race_id,
    standings.driver_id,
    standings.points_change,
    coalesce(race_points.points, 0) + coalesce(sprint_points.points, 0) as expected_change

from standings
left join race_points
    on standings.race_id = race_points.race_id
    and standings.driver_id = race_points.driver_id
left join sprint_points
    on standings.race_id = sprint_points.race_id
    and standings.driver_id = sprint_points.driver_id
where abs(standings.points_change - (coalesce(race_points.points, 0) + coalesce(sprint_points.points, 0))) > 0.01
