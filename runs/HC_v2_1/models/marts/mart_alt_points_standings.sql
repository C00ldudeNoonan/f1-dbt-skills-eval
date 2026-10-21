{#
    What-if standings: every driver with at least one Grand Prix result in a season, re-scored under
    the points system named by the points_system var (default f1_current, see seeds/points_systems.csv).

    Rules:
      - Only classified finishers score, and only for position_order 1 to 10 under the system.
      - Each result entry scores on its own. Two cars for one driver in one race both score.
      - Sprints and fastest-lap points are not counted. This model reads fct_results, which is Grand Prix only.
      - Rank: alt_points descending, then countback (wins, second places, through tenth), then lowest driver_id.

    To score under another system, add its rows to the points_systems seed and set the var. The table
    holds one system at a time, so a run replaces the previous system's scores.
#}
with points as (

    select
        position,
        points
    from {{ ref('points_systems') }}
    where system_name = '{{ var("points_system") }}'

),

results as (

    select
        season,
        driver_id,
        position_order,
        finish_position
    from {{ ref('fct_results') }}

),

driver_seasons as (

    select
        results.season,
        results.driver_id,
        coalesce(sum(points.points), 0) as alt_points,
        {%- for position in range(1, 11) %}
        count_if(results.finish_position is not null and results.position_order = {{ position }}) as finishes_at_{{ position }}{{ ',' if not loop.last }}
        {%- endfor %}
    from results
    left join points
        on results.finish_position is not null
        and results.position_order = points.position
    group by results.season, results.driver_id

)

select
    '{{ var("points_system") }}' as points_system,
    season,
    driver_id,
    alt_points,
    row_number() over (
        partition by season
        order by
            alt_points desc,
            {%- for position in range(1, 11) %}
            finishes_at_{{ position }} desc,
            {%- endfor %}
            driver_id asc
    ) as alt_position
from driver_seasons
