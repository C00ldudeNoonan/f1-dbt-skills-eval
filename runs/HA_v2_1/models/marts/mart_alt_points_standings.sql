{#
    Grain: one row per points system, season and driver, for every driver with at least one
    Grand Prix result that season.

    Scoring: only classified results (finish_position not null) score, and each result entry
    scores on its own. The points awarded are looked up by position_order in the points_systems
    seed. Sprints and fastest-lap points are not used.

    Ranking: alt_points descending, then countback on the number of finishes at each position
    from 1 up to countback_max_position (more wins, then more 2nd places, and so on), then the
    lowest driver_id.

    To add a points system, add rows to the points_systems seed. This model needs no SQL change.
#}
{% set max_position = var('countback_max_position') %}

with systems as (

    select points_system, position, points
    from {{ ref('points_systems') }}

),

results as (

    select season, driver_id, position_order
    from {{ ref('fct_results') }}

),

driver_seasons as (

    select distinct season, driver_id
    from results

),

classified as (

    select season, driver_id, position_order
    from {{ ref('fct_results') }}
    where finish_position is not null

),

finish_counts as (

    select
        season,
        driver_id,
        {% for p in range(1, max_position + 1) %}
        count_if(position_order = {{ p }}) as finishes_p{{ p }}{{ "," if not loop.last }}
        {% endfor %}
    from classified
    group by season, driver_id

),

system_points as (

    select
        systems.points_system,
        classified.season,
        classified.driver_id,
        sum(systems.points) as alt_points
    from classified
    inner join systems
        on classified.position_order = systems.position
    group by systems.points_system, classified.season, classified.driver_id

),

scored as (

    select
        systems.points_system,
        driver_seasons.season,
        driver_seasons.driver_id,
        coalesce(system_points.alt_points, 0) as alt_points,
        {% for p in range(1, max_position + 1) %}
        coalesce(finish_counts.finishes_p{{ p }}, 0) as finishes_p{{ p }}{{ "," if not loop.last }}
        {% endfor %}
    from driver_seasons
    cross join (select distinct points_system from systems) as systems
    left join system_points
        on systems.points_system = system_points.points_system
        and driver_seasons.season = system_points.season
        and driver_seasons.driver_id = system_points.driver_id
    left join finish_counts
        on driver_seasons.season = finish_counts.season
        and driver_seasons.driver_id = finish_counts.driver_id

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
            {% for p in range(1, max_position + 1) %}
            finishes_p{{ p }} desc,
            {% endfor %}
            driver_id
    ) as alt_position
from scored
