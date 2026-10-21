{#-
  Teammate head-to-head per season and constructor, in both orderings.
  A pair is included when both drivers had a Grand Prix result for the same
  constructor in the same race at least once that season.
-#}
with entries as (
    select
        entries.race_id,
        races.season,
        entries.constructor_id,
        entries.driver_id,
        entries.best_position_order
    from {{ ref('int_race_driver_constructors') }} as entries
    inner join {{ ref('stg_ergast__races') }} as races
        on entries.race_id = races.race_id
),

race_pairs as (
    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id                                          as teammate_id,
        count(distinct driver.race_id)                              as races_together,
        count(distinct iff(driver.best_position_order < teammate.best_position_order,
                           driver.race_id, null))                   as races_ahead
    from entries as driver
    inner join entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
    group by 1, 2, 3, 4
),

qualifying as (
    select
        q.race_id,
        races.season,
        q.constructor_id,
        q.driver_id,
        min(q.qualifying_position) as qualifying_position
    from {{ ref('stg_ergast__qualifying') }} as q
    inner join {{ ref('stg_ergast__races') }} as races
        on q.race_id = races.race_id
    group by 1, 2, 3, 4
),

qualifying_pairs as (
    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id                                          as teammate_id,
        count(distinct driver.race_id)                              as qualifying_together,
        count(distinct iff(driver.qualifying_position < teammate.qualifying_position,
                           driver.race_id, null))                   as qualifying_ahead
    from qualifying as driver
    inner join qualifying as teammate
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
    coalesce(qualifying_pairs.qualifying_together, 0)   as qualifying_together,
    coalesce(qualifying_pairs.qualifying_ahead, 0)      as qualifying_ahead
from race_pairs
left join qualifying_pairs
    on race_pairs.season = qualifying_pairs.season
    and race_pairs.constructor_id = qualifying_pairs.constructor_id
    and race_pairs.driver_id = qualifying_pairs.driver_id
    and race_pairs.teammate_id = qualifying_pairs.teammate_id
