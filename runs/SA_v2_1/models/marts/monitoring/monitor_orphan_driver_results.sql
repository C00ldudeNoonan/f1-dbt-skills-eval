{{ config(materialized='view') }}

-- Results whose driver_id has no record in `drivers` yet (late-arriving drivers).
-- One row per such driver; `select sum(orphan_results)` gives the running total.
-- Rows disappear on their own once the real driver record arrives.
select
    results.driver_id,
    count(*) as orphan_results,
    count(distinct results.race_id) as orphan_races,
    min(results.race_date) as first_race_date,
    max(results.race_date) as last_race_date
from {{ ref('fct_results') }} as results
where results.driver_id not in (select driver_id from {{ ref('stg_ergast__drivers') }})
group by results.driver_id
