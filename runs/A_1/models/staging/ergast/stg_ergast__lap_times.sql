{#
  Per-lap timing (1996+). `milliseconds` is the authoritative lap time; the
  `time` text is display-only and cannot be parsed reliably (laps over an hour,
  e.g. behind a red flag, render as H:MM:SS.mmm).
#}

with source as (
    select * from {{ source('ergast', 'lap_times') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('raceid') }}          as race_id,
    {{ to_int('driverid') }}        as driver_id,
    {{ to_int('lap') }}             as lap,
    {{ to_int('position') }}        as position,
    {{ clean_text('time') }}        as lap_time_text,
    {{ to_int('milliseconds') }}    as lap_time_ms
from source
