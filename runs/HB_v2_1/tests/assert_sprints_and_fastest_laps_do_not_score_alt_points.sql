{#
    alt_points under the current system must come only from classified Grand Prix finishes.
    Recomputed here from the seed and fct_results, this must match the mart for every driver.
#}
with expected as (

    select
        results.season,
        results.driver_id,
        sum(rules.points) as expected_points

    from {{ ref('fct_results') }} as results
    inner join {{ ref('points_systems') }} as rules
        on rules.points_system = 'current'
        and results.position_order = rules.position_order
        and results.season between rules.first_season and rules.last_season
    where results.finish_position is not null
    group by results.season, results.driver_id

)

select
    standings.season,
    standings.driver_id,
    standings.alt_points,
    coalesce(expected.expected_points, 0) as expected_points

from {{ ref('mart_alt_points_standings') }} as standings
left join expected
    on standings.season = expected.season
    and standings.driver_id = expected.driver_id
where standings.points_system = 'current'
    and standings.alt_points <> coalesce(expected.expected_points, 0)
