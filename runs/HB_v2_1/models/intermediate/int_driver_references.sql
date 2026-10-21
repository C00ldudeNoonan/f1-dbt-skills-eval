{#
    Every place a driver_id appears in the fact data, with the race it came from.
    Used to find results and other rows whose driver has no record in stg_f1__drivers
    (late-arriving drivers).
#}
select driver_id, race_id, 'results' as source_table from {{ ref('stg_f1__results') }}

union all

select driver_id, race_id, 'qualifying' from {{ ref('stg_f1__qualifying') }}

union all

select driver_id, race_id, 'pit_stops' from {{ ref('stg_f1__pit_stops') }}

union all

select driver_id, race_id, 'lap_times' from {{ ref('stg_f1__lap_times') }}

union all

select driver_id, race_id, 'driver_standings' from {{ ref('stg_f1__driver_standings') }}
