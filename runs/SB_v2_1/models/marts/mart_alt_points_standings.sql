-- Grain: one row per points system, season and driver (every driver with at least one Grand Prix
-- result that season). Scoring is data-driven by the alt_points_systems seed: a classified finish at
-- position_order N scores seed points for N. Every result entry scores on its own (shared drives
-- included); sprints and fastest-lap points are not counted.
-- Rank: points desc, then countback (more 1sts, 2nds ... 10ths), then lowest driver_id.
with entries as (
    select season, driver_id, finish_position
    from {{ ref('fct_results') }}
),

driver_seasons as (
    select distinct season, driver_id from entries
),

systems as (
    select distinct points_system from {{ ref('alt_points_systems') }}
),

scored as (
    select
        systems.points_system,
        entries.season,
        entries.driver_id,
        sum(scoring.points) as alt_points
    from entries
    cross join systems
    inner join {{ ref('alt_points_systems') }} as scoring
        on scoring.points_system = systems.points_system
        and scoring.position_order = entries.finish_position
    group by 1, 2, 3
),

countback as (
    select
        season,
        driver_id,
        {% for n in range(1, 11) %}
        count_if(finish_position = {{ n }}) as finishes_{{ n }}{{ "," if not loop.last }}
        {% endfor %}
    from entries
    group by 1, 2
),

joined as (
    select
        systems.points_system,
        driver_seasons.season,
        driver_seasons.driver_id,
        coalesce(scored.alt_points, 0)::number(12, 2) as alt_points,
        countback.*  exclude (season, driver_id)
    from driver_seasons
    cross join systems
    left join scored
        on scored.points_system = systems.points_system
        and scored.season = driver_seasons.season
        and scored.driver_id = driver_seasons.driver_id
    inner join countback
        on countback.season = driver_seasons.season
        and countback.driver_id = driver_seasons.driver_id
)

select
    season,
    driver_id,
    points_system,
    alt_points,
    row_number() over (
        partition by points_system, season
        order by
            alt_points desc,
            {% for n in range(1, 11) %}finishes_{{ n }} desc, {% endfor %}
            driver_id asc
    )::integer as alt_position
from joined
