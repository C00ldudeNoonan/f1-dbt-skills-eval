{#
    One row per season, constructor, driver and teammate, for every pair of drivers who
    shared a constructor in the same Grand Prix at least once. Both orderings are present.

    A driver's race position is their best position_order in that race for that constructor.
    Their qualifying position is their position in that race for that constructor.
    Lower is better for both.
#}
with race_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order
    from {{ ref('fct_results') }}
    group by season, race_id, constructor_id, driver_id

),

qualifying_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        qualifying_position
    from {{ ref('fct_qualifying') }}

),

race_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.best_position_order as driver_position,
        teammate.best_position_order as teammate_position
    from race_entries as driver
    inner join race_entries as teammate
        on driver.season = teammate.season
        and driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

),

qualifying_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.qualifying_position as driver_position,
        teammate.qualifying_position as teammate_position
    from qualifying_entries as driver
    inner join qualifying_entries as teammate
        on driver.season = teammate.season
        and driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

),

race_summary as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(*) as races_together,
        count_if(driver_position < teammate_position) as races_ahead
    from race_pairs
    group by season, constructor_id, driver_id, teammate_id

),

qualifying_summary as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(*) as qualifying_together,
        count_if(driver_position < teammate_position) as qualifying_ahead
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
