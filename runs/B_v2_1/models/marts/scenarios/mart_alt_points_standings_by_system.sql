{#-
  What-if drivers' championship: every season re-scored under every points
  system in seeds/points_systems.csv. One row per points system, season and
  driver with at least one Grand Prix result that season.

  Rules:
    - Grand Prix results only (no sprints, no fastest-lap or other bonus points).
    - Only classified finishers score; points are looked up by position_order.
    - Every result entry scores on its own (shared drives and two-car entries
      both count), with no drop scores.
    - Rank by alt_points desc, then countback (more 1st places, then more 2nd
      places, ... through alt_points_countback_depth), then lowest driver_id.
-#}
{%- set depth = var('alt_points_countback_depth') -%}

with results as (
    select
        season,
        driver_id,
        position_order,
        finish_position is not null as is_classified
    from {{ ref('fct_results') }}
),

points_systems as (
    select * from {{ ref('points_systems') }}
),

systems as (
    select distinct points_system from points_systems
),

scored as (
    select
        systems.points_system,
        results.season,
        results.driver_id,
        coalesce(points_systems.points, 0)  as entry_points,
        results.position_order,
        results.is_classified
    from results
    cross join systems
    left join points_systems
        on systems.points_system = points_systems.points_system
        and results.position_order = points_systems.finish_position_order
        and results.is_classified
),

totals as (
    select
        points_system,
        season,
        driver_id,
        sum(entry_points)::number(10, 2)    as alt_points
        {%- for place in range(1, depth + 1) %},
        count_if(is_classified and position_order = {{ place }}) as p{{ place }}_count
        {%- endfor %}
    from scored
    group by points_system, season, driver_id
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
            {%- for place in range(1, depth + 1) %}
            p{{ place }}_count desc,
            {%- endfor %}
            driver_id asc
    )                                       as alt_position,
    p1_count                                as alt_wins
from totals
