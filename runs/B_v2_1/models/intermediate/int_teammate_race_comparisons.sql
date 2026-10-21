{#-
  One row per Grand Prix, constructor, driver and teammate (both orderings)
  where both drivers were classified finishers. Retirements are excluded
  because most are mechanical (the car, not the driver) and the data can't
  reliably separate driver-caused retirements. This also removes crashes
  that were the driver's fault: a known bias in favour of crash-prone drivers.
-#}
with entries as (
    select
        race_id,
        season,
        constructor_id,
        driver_id,
        min(finish_position) as finish_position,
        sum(points) as points
    from {{ ref('fct_results') }}
    group by race_id, season, constructor_id, driver_id
)

select
    driver.race_id,
    driver.season,
    driver.constructor_id,
    driver.driver_id,
    teammate.driver_id                                  as teammate_id,
    driver.finish_position,
    teammate.finish_position                            as teammate_finish_position,
    driver.finish_position < teammate.finish_position   as finished_ahead
from entries as driver
inner join entries as teammate
    on driver.race_id = teammate.race_id
    and driver.constructor_id = teammate.constructor_id
    and driver.driver_id <> teammate.driver_id
where driver.finish_position is not null
    and teammate.finish_position is not null
