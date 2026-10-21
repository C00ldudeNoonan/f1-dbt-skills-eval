with source as (
    select * from {{ source('ergast', 'pit_stops') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('raceid') }}              as race_id,
    {{ to_int('driverid') }}            as driver_id,
    {{ to_int('stop') }}                as stop_number,
    {{ to_int('lap') }}                 as lap,
    try_to_time({{ clean_text('time') }}) as stop_time_of_day,
    {{ to_int('milliseconds') }}        as duration_ms,
    {{ to_int('milliseconds') }} / 1000.0 as duration_seconds
from source
