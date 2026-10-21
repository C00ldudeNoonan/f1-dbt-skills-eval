{#
    What-if championship scoring. One row per points system, driver and season, for every
    driver with at least one Grand Prix result that season.

    Points come from the points_systems seed. Each Grand Prix entry scores on its own when it
    is classified, using its position_order. Sprints and fastest-lap points do not count.

    alt_position ranks by alt_points descending, then countback on finishing counts: wins,
    second places, through tenth places. Any remaining tie goes to the lowest driver_id.

    Adding a points system is a seed change. Positions 1 to 10 are fixed for the countback,
    matching the finishing counts used in the ranking.
#}
with results as (

    select
        season,
        driver_id,
        race_id,
        position_order,
        finish_position

    from {{ ref('fct_results') }}

),

driver_seasons as (

    select distinct
        season,
        driver_id

    from results

),

points_rules as (

    select * from {{ ref('points_systems') }}

),

system_seasons as (

    select distinct
        driver_seasons.season,
        driver_seasons.driver_id,
        points_rules.points_system

    from driver_seasons
    inner join points_rules
        on driver_seasons.season between points_rules.first_season and points_rules.last_season

),

scored as (

    select
        points_rules.points_system,
        results.season,
        results.driver_id,
        sum(points_rules.points) as alt_points

    from results
    inner join points_rules
        on results.position_order = points_rules.position_order
        and results.season between points_rules.first_season and points_rules.last_season
    where results.finish_position is not null
    group by points_rules.points_system, results.season, results.driver_id

),

finishing_counts as (

    select
        season,
        driver_id,
        count_if(finish_position = 1) as finishes_1,
        count_if(finish_position = 2) as finishes_2,
        count_if(finish_position = 3) as finishes_3,
        count_if(finish_position = 4) as finishes_4,
        count_if(finish_position = 5) as finishes_5,
        count_if(finish_position = 6) as finishes_6,
        count_if(finish_position = 7) as finishes_7,
        count_if(finish_position = 8) as finishes_8,
        count_if(finish_position = 9) as finishes_9,
        count_if(finish_position = 10) as finishes_10

    from results
    group by season, driver_id

),

standings as (

    select
        system_seasons.points_system,
        system_seasons.season,
        system_seasons.driver_id,
        coalesce(scored.alt_points, 0) as alt_points,
        finishing_counts.finishes_1 as wins,
        finishing_counts.finishes_1,
        finishing_counts.finishes_2,
        finishing_counts.finishes_3,
        finishing_counts.finishes_4,
        finishing_counts.finishes_5,
        finishing_counts.finishes_6,
        finishing_counts.finishes_7,
        finishing_counts.finishes_8,
        finishing_counts.finishes_9,
        finishing_counts.finishes_10

    from system_seasons
    left join scored
        on system_seasons.points_system = scored.points_system
        and system_seasons.season = scored.season
        and system_seasons.driver_id = scored.driver_id
    left join finishing_counts
        on system_seasons.season = finishing_counts.season
        and system_seasons.driver_id = finishing_counts.driver_id

)

select
    points_system,
    season,
    driver_id,
    alt_points,
    wins,
    row_number() over (
        partition by points_system, season
        order by
            alt_points desc,
            finishes_1 desc,
            finishes_2 desc,
            finishes_3 desc,
            finishes_4 desc,
            finishes_5 desc,
            finishes_6 desc,
            finishes_7 desc,
            finishes_8 desc,
            finishes_9 desc,
            finishes_10 desc,
            driver_id asc
    ) as alt_position

from standings
