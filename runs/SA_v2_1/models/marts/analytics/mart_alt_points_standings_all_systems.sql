-- Re-scores every Grand Prix season under each system in the points_systems seed.
-- Only classified finishers score, each result entry scores on its own (shared drives
-- included), points are looked up by position_order, and sprints / fastest laps never count.
-- Ranking: points desc, then countback (more 1sts, then 2nds ... through 10th), then lowest driver_id.
with entries as (

    select season, driver_id, position_order, finish_position
    from {{ ref('fct_results') }}

),

driver_seasons as (

    select
        season,
        driver_id,
        {% for n in range(1, 11) %}
        count_if(finish_position is not null and position_order = {{ n }}) as finishes_{{ n }}{{ "," if not loop.last }}
        {% endfor %}
    from entries
    group by season, driver_id

),

systems as (

    select distinct points_system from {{ ref('points_systems') }}

),

scored as (

    select
        entries.season,
        entries.driver_id,
        systems.points_system,
        sum(coalesce(points_systems.points, 0)) as alt_points
    from entries
    cross join systems
    left join {{ ref('points_systems') }} as points_systems
        on points_systems.points_system = systems.points_system
        and points_systems.position_order = entries.position_order
        and entries.finish_position is not null
    group by entries.season, entries.driver_id, systems.points_system

)

select
    scored.points_system,
    scored.season,
    scored.driver_id,
    scored.alt_points,
    row_number() over (
        partition by scored.points_system, scored.season
        order by
            scored.alt_points desc,
            {% for n in range(1, 11) %}
            driver_seasons.finishes_{{ n }} desc,
            {% endfor %}
            scored.driver_id asc
    ) as alt_position
from scored
inner join driver_seasons
    on scored.season = driver_seasons.season
    and scored.driver_id = driver_seasons.driver_id
