{#-
  Every driver_id referenced by any driver-keyed feed, flagged with whether a
  record exists in `drivers`. The results feed can deliver a rookie or reserve
  driver's result before their driver record lands; those ids still need a row
  in dim_drivers so nothing downstream drops or breaks.
-#}
with referenced as (
    select driver_id from {{ ref('stg_ergast__results') }}
    union
    select driver_id from {{ ref('stg_ergast__sprint_results') }}
    union
    select driver_id from {{ ref('stg_ergast__qualifying') }}
    union
    select driver_id from {{ ref('stg_ergast__driver_standings') }}
    union
    select driver_id from {{ ref('stg_ergast__lap_times') }}
    union
    select driver_id from {{ ref('stg_ergast__pit_stops') }}
),

drivers as (
    select driver_id from {{ ref('stg_ergast__drivers') }}
)

select
    coalesce(drivers.driver_id, referenced.driver_id)   as driver_id,
    drivers.driver_id is not null                       as has_driver_record
from drivers
full outer join referenced
    on drivers.driver_id = referenced.driver_id
