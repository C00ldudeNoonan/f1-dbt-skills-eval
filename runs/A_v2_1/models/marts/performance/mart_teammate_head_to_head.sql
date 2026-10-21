-- Teammate head-to-head per season and constructor, in both orderings.
-- The pair population comes from Grand Prix results; qualifying comparisons are
-- attached to those pairs.
with results as (

    select * from {{ ref('fct_results') }}

),

qualifying as (

    select * from {{ ref('fct_qualifying') }}

),

-- A driver can have several results in one race before 1979 (shared or second
-- cars), so collapse to their best classified order per race and constructor.
race_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order
    from results
    group by 1, 2, 3, 4

),

race_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        count(distinct driver.race_id) as races_together,
        count(distinct iff(driver.best_position_order < teammate.best_position_order,
            driver.race_id, null)) as races_ahead
    from race_entries as driver
    inner join race_entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id != teammate.driver_id
    group by 1, 2, 3, 4

),

qualifying_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(qualifying_position) as qualifying_position
    from qualifying
    group by 1, 2, 3, 4

),

qualifying_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        count(distinct driver.race_id) as qualifying_together,
        count(distinct iff(driver.qualifying_position < teammate.qualifying_position,
            driver.race_id, null)) as qualifying_ahead
    from qualifying_entries as driver
    inner join qualifying_entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id != teammate.driver_id
    group by 1, 2, 3, 4

)

select
    race_pairs.season,
    race_pairs.constructor_id,
    race_pairs.driver_id,
    race_pairs.teammate_id,
    race_pairs.races_together,
    race_pairs.races_ahead,
    coalesce(qualifying_pairs.qualifying_together, 0) as qualifying_together,
    coalesce(qualifying_pairs.qualifying_ahead, 0) as qualifying_ahead
from race_pairs
left join qualifying_pairs
    on race_pairs.season = qualifying_pairs.season
    and race_pairs.constructor_id = qualifying_pairs.constructor_id
    and race_pairs.driver_id = qualifying_pairs.driver_id
    and race_pairs.teammate_id = qualifying_pairs.teammate_id
