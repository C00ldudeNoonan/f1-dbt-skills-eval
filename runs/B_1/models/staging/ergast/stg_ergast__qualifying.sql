with source as (
    select * from {{ source('ergast', 'qualifying') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('qualifyid') }}       as qualifying_id,
    {{ ergast_int('raceid') }}          as race_id,
    {{ ergast_int('driverid') }}        as driver_id,
    {{ ergast_int('constructorid') }}   as constructor_id,
    {{ ergast_int('number') }}          as car_number,
    {{ ergast_int('position') }}        as qualifying_position,
    {{ lap_time_to_ms('q1') }}          as q1_time_ms,
    {{ lap_time_to_ms('q2') }}          as q2_time_ms,
    {{ lap_time_to_ms('q3') }}          as q3_time_ms
from source
