{{ config(materialized='view') }}

-- Grand Prix results whose driver_id has no record in DRIVERS yet. A view over
-- the staging views, so querying it always reflects the raw data right now:
--   select count(*) from audit_orphan_driver_results
-- Rows disappear on their own once the driver record arrives.
select
    results.result_id,
    results.race_id,
    races.season,
    races.round,
    results.driver_id,
    results.constructor_id,
    results.position_order,
    results.points
from {{ ref('stg_ergast__results') }} as results
left join {{ ref('stg_ergast__races') }} as races
    on results.race_id = races.race_id
where results.driver_id not in (select driver_id from {{ ref('stg_ergast__drivers') }})
