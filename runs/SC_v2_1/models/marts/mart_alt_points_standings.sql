{#- Re-scores every Grand Prix under a points system defined as data in
    seeds/ref_points_systems.csv (one row per position_order). To add a system, add rows
    to the seed; to use it, set the `alt_points_system` var (default current_2010).
    Rules: only classified finishers score, each result entry scores separately, points
    follow position_order, sprints and fastest-lap points are ignored. Ties break on
    countback (most 1sts, then most 2nds, ... through 10th) then lowest driver_id. -#}
{% set points_system = var('alt_points_system') %}
{% set countback_depth = 10 %}

with entries as (

    select season, driver_id, position_order, finish_position
    from {{ ref('fct_results') }}

),

scoring as (

    select position_order, points
    from {{ ref('ref_points_systems') }}
    where points_system = '{{ points_system }}'

),

scored as (

    select
        entries.season,
        entries.driver_id,
        entries.position_order,
        coalesce(entries.finish_position is not null, false) as is_classified,
        coalesce(scoring.points, 0) as points
    from entries
    left join scoring on scoring.position_order = entries.position_order

),

driver_seasons as (

    select
        season,
        driver_id,
        sum(iff(is_classified, points, 0)) as alt_points
    from scored
    group by season, driver_id

),

positions as (

    select row_number() over (order by seq4()) as position_order
    from table(generator(rowcount => {{ countback_depth }}))

),

finishes_by_position as (

    select
        driver_seasons.season,
        driver_seasons.driver_id,
        positions.position_order,
        count_if(scored.is_classified) as finishes
    from driver_seasons
    cross join positions
    left join scored
        on scored.season = driver_seasons.season
        and scored.driver_id = driver_seasons.driver_id
        and scored.position_order = positions.position_order
    group by all

),

-- sortable key: zero-padded count of classified finishes at 1st, 2nd, ... 10th
countback as (

    select
        season,
        driver_id,
        listagg(lpad(finishes::varchar, 3, '0')) within group (order by position_order) as countback_key
    from finishes_by_position
    group by season, driver_id

)

select
    driver_seasons.season,
    driver_seasons.driver_id,
    driver_seasons.alt_points::number(8, 2) as alt_points,
    row_number() over (
        partition by driver_seasons.season
        order by driver_seasons.alt_points desc, countback.countback_key desc, driver_seasons.driver_id asc
    )::integer as alt_position,
    '{{ points_system }}' as points_system
from driver_seasons
inner join countback
    on countback.season = driver_seasons.season
    and countback.driver_id = driver_seasons.driver_id
