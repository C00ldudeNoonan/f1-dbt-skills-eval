-- What-if drivers' championship: every season re-scored under every points
-- system in the points_systems seed. One row per points system, season and
-- driver with at least one Grand Prix result that season.
--
-- Scoring: each classified Grand Prix result entry scores the points for its
-- position_order on its own, so shared drives score in full. No sprint or
-- fastest-lap points. Ranking: alt_points descending, then countback (more
-- 1st places, then 2nd places, and so on through 10th), then lowest driver_id.

{% set countback_depth = 10 %}

with results as (
    select * from {{ ref('fct_results') }}
),

points_systems as (
    select * from {{ ref('points_systems') }}
),

systems as (
    select distinct points_system
    from points_systems
),

season_drivers as (
    select distinct
        season,
        driver_id
    from results
),

classified_results as (
    select
        season,
        driver_id,
        position_order
    from results
    where finish_position is not null
),

countback as (
    select
        season,
        driver_id,
        {% for position in range(1, countback_depth + 1) %}
        count_if(position_order = {{ position }}) as finishes_p{{ position }}{{ "," if not loop.last }}
        {% endfor %}
    from classified_results
    group by season, driver_id
),

scored as (
    select
        systems.points_system,
        season_drivers.season,
        season_drivers.driver_id,
        coalesce(sum(points_systems.points), 0) as alt_points
    from season_drivers
    cross join systems
    left join classified_results
        on season_drivers.season = classified_results.season
        and season_drivers.driver_id = classified_results.driver_id
    left join points_systems
        on systems.points_system = points_systems.points_system
        and classified_results.position_order = points_systems.position_order
    group by systems.points_system, season_drivers.season, season_drivers.driver_id
)

select
    scored.points_system,
    scored.season,
    scored.driver_id,
    scored.alt_points::number(8, 2) as alt_points,
    row_number() over (
        partition by scored.points_system, scored.season
        order by
            scored.alt_points desc,
            {% for position in range(1, countback_depth + 1) %}
            coalesce(countback.finishes_p{{ position }}, 0) desc,
            {% endfor %}
            scored.driver_id
    )::integer as alt_position,
    coalesce(countback.finishes_p1, 0)::integer as alt_wins
from scored
left join countback
    on scored.season = countback.season
    and scored.driver_id = countback.driver_id
