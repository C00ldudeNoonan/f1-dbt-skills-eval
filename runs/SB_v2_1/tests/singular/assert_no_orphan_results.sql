{{ config(severity='warn') }}
-- Warns (does not fail) while any result references a driver missing from the drivers table.
select * from {{ ref('audit_results_missing_driver') }}
