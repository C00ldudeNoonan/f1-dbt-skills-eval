{{ config(materialized='view') }}
-- Orphan results: Grand Prix results whose driver_id has no record in the raw drivers table yet.
-- Count them any time with: select count(*) from audit_results_missing_driver
select
    results.result_id,
    results.race_id,
    results.season,
    results.round,
    results.driver_id
from {{ ref('fct_results') }} as results
left join {{ ref('stg_f1__drivers') }} as drivers on drivers.driver_id = results.driver_id
where drivers.driver_id is null
