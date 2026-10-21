{{ config(severity='warn') }}
-- Warns (does not fail the build) while any result references a driver missing from raw `drivers`.
select * from {{ ref('mart_orphan_driver_results') }}
