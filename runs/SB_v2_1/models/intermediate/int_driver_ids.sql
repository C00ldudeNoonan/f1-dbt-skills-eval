-- Every driver_id referenced by any driver-keyed feed, whether or not the drivers table knows it yet.
-- Feeds a placeholder row in dim_drivers for late-arriving drivers.
select driver_id from {{ ref('stg_f1__results') }}
union
select driver_id from {{ ref('stg_f1__qualifying') }}
union
select driver_id from {{ ref('stg_f1__driver_standings') }}
union
select driver_id from {{ ref('stg_f1__lap_times') }}
union
select driver_id from {{ ref('stg_f1__pit_stops') }}
union
select driver_id from {{ ref('stg_f1__sprint_results') }}
