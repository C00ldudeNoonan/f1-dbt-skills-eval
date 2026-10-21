{{ config(severity='warn') }}
-- Warns (does not fail) while any result is waiting for its driver record.
select * from {{ ref('monitor_orphan_driver_results') }}
