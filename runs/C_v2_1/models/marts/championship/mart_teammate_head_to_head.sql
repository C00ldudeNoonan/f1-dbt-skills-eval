-- Teammate comparisons within a season and constructor, in both orderings
-- (driver vs teammate and teammate vs driver).

with results as (
    select * from {{ ref('fct_results') }}
),

driver_race as (
    -- A driver's best classified-order position for a constructor in a race
    -- (shared drives before 1979 can give several rows).
    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order
    from results
    group by season, race_id, constructor_id, driver_id
),

race_pairs as (
    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        count(distinct driver.race_id) as races_together,
        count(distinct case
            when driver.best_position_order < teammate.best_position_order then driver.race_id
        end) as races_ahead
    from driver_race as driver
    inner join driver_race as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
    group by 1, 2, 3, 4
),

driver_qualifying as (
    -- Qualifying attributed to the constructor the driver raced for (see
    -- int_f1__qualifying_entries).
    select
        season,
        race_id,
        constructor_id,
        driver_id,
        qualifying_position
    from {{ ref('int_f1__qualifying_entries') }}
),

qualifying_pairs as (
    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        count(distinct driver.race_id) as qualifying_together,
        count(distinct case
            when driver.qualifying_position < teammate.qualifying_position then driver.race_id
        end) as qualifying_ahead
    from driver_qualifying as driver
    inner join driver_qualifying as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
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
