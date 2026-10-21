-- Warns (does not fail) while results reference drivers with no `drivers` record.
-- The warning's failure count is the number of drivers affected; see
-- audit_orphan_driver_results for the individual results.
{{ config(severity='warn') }}

select driver_id, count(*) as orphan_results
from {{ ref('audit_orphan_driver_results') }}
group by driver_id
