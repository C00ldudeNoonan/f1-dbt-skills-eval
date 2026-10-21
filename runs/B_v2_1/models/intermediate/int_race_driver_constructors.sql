{#-
  One row per race, driver and constructor that has a Grand Prix result.
  Collapses the rare pre-1979 case of a driver with two cars in one race
  for the same team down to the driver's best position_order.
-#}
select
    race_id,
    driver_id,
    constructor_id,
    min(position_order) as best_position_order
from {{ ref('stg_ergast__results') }}
group by race_id, driver_id, constructor_id
