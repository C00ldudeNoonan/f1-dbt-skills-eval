with source as (
    select * from {{ source('ergast', 'lap_times') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('raceid') }}          as race_id,
    {{ ergast_int('driverid') }}        as driver_id,
    {{ ergast_int('lap') }}             as lap,
    {{ ergast_int('position') }}        as position,
    {{ ergast_clean('time') }}          as lap_time_text,
    {{ ergast_int('milliseconds') }}    as lap_time_ms
from source
