{#
    Driver against teammate, one row per season, constructor, driver and teammate.
    Both orderings appear (driver A vs B and B vs A).

    Rows exist for pairs that shared a constructor in at least one Grand Prix.
    Race comparisons use each driver's best position_order in that race.
    Qualifying comparisons use qualifying entries, which can exist without a
    matching race result, so they are aggregated on their own and joined in.
#}
with entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order

    from {{ ref('fct_results') }}
    group by season, race_id, constructor_id, driver_id

),

race_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.race_id,
        driver.best_position_order < teammate.best_position_order as is_ahead

    from entries as driver
    inner join entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

),

race_summary as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(distinct race_id) as races_together,
        count_if(is_ahead) as races_ahead

    from race_pairs
    group by season, constructor_id, driver_id, teammate_id

),

qualifying_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        position

    from {{ ref('fct_qualifying') }}

),

qualifying_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.race_id,
        driver.position < teammate.position as is_ahead

    from qualifying_entries as driver
    inner join qualifying_entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

),

qualifying_summary as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(distinct race_id) as qualifying_together,
        count_if(is_ahead) as qualifying_ahead

    from qualifying_pairs
    group by season, constructor_id, driver_id, teammate_id

)

select
    race_summary.season,
    race_summary.constructor_id,
    race_summary.driver_id,
    race_summary.teammate_id,
    race_summary.races_together,
    race_summary.races_ahead,
    coalesce(qualifying_summary.qualifying_together, 0) as qualifying_together,
    coalesce(qualifying_summary.qualifying_ahead, 0) as qualifying_ahead

from race_summary
left join qualifying_summary
    on race_summary.season = qualifying_summary.season
    and race_summary.constructor_id = qualifying_summary.constructor_id
    and race_summary.driver_id = qualifying_summary.driver_id
    and race_summary.teammate_id = qualifying_summary.teammate_id
