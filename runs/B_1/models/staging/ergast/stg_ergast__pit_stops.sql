with source as (
    select * from {{ source('ergast', 'pit_stops') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('raceid') }}                      as race_id,
    {{ ergast_int('driverid') }}                    as driver_id,
    {{ ergast_int('stop') }}                        as stop_number,
    {{ ergast_int('lap') }}                         as lap,
    {{ ergast_clean('time') }}                      as time_of_day_text,
    -- The vendor dropped the redundant text `duration` column in their 2026-10
    -- pipeline migration; milliseconds is the source of truth.
    {{ ergast_int('milliseconds') }}                as duration_ms,
    {{ ergast_int('milliseconds') }} / 1000.0       as duration_seconds
from source
