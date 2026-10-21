{#-
    What-if Drivers' Championship: every season re-scored under each points
    system in the points_systems seed. Adding a system is a data change: add
    rows to seeds/points_systems.csv and run dbt build.

    Rules (applied identically for every system):
      * Grand Prix results only (no sprints, no fastest-lap points).
      * Only classified finishers score, by position_order.
      * Every result entry scores on its own (shared drives both score).
      * No dropped scores.
      * Rank by alt_points desc, then countback (most wins, then most 2nds, ...
        through var('alt_points_countback_depth') = 10th), then lowest driver_id.
    Every driver with at least one Grand Prix result in the season gets a row
    for every system, even with zero points.
-#}
{%- set countback_depth = var('alt_points_countback_depth') -%}

with results as (

    select * from {{ ref('fct_results') }}

),

points_systems as (

    select * from {{ ref('points_systems') }}

),

season_drivers as (

    select distinct season, driver_id from results

),

classified as (

    select season, driver_id, position_order
    from results
    where is_classified

),

scored as (

    select
        points_systems.points_system,
        classified.season,
        classified.driver_id,
        sum(points_systems.points) as alt_points
    from classified
    inner join points_systems
        on classified.position_order = points_systems.position
    group by 1, 2, 3

),

countback as (

    select
        season,
        driver_id
        {%- for p in range(1, countback_depth + 1) %},
        count_if(position_order = {{ p }}) as finishes_p{{ p }}
        {%- endfor %}
    from classified
    group by 1, 2

),

systems as (

    select distinct points_system from points_systems

),

combined as (

    select
        systems.points_system,
        season_drivers.season,
        season_drivers.driver_id,
        coalesce(scored.alt_points, 0) as alt_points
        {%- for p in range(1, countback_depth + 1) %},
        coalesce(countback.finishes_p{{ p }}, 0) as finishes_p{{ p }}
        {%- endfor %}
    from season_drivers
    cross join systems
    left join scored
        on systems.points_system = scored.points_system
        and season_drivers.season = scored.season
        and season_drivers.driver_id = scored.driver_id
    left join countback
        on season_drivers.season = countback.season
        and season_drivers.driver_id = countback.driver_id

)

select
    points_system,
    season,
    driver_id,
    alt_points,
    row_number() over (
        partition by points_system, season
        order by
            alt_points desc,
            {%- for p in range(1, countback_depth + 1) %}
            finishes_p{{ p }} desc,
            {%- endfor %}
            driver_id
    ) as alt_position,
    finishes_p1 as alt_wins
from combined
