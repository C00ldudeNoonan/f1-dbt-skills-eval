select
    {{ to_int('raceid') }} as race_id,
    {{ to_int('driverid') }} as driver_id,
    {{ to_int('stop') }} as stop_number,
    {{ to_int('lap') }} as lap,
    {{ clean_text('time') }} as time_of_day,
    -- The vendor dropped the redundant text DURATION column in October 2026;
    -- milliseconds was always the authoritative duration.
    {{ to_int('milliseconds') }} as duration_ms
from {{ source('ergast', 'pit_stops') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'driver_id', 'stop_number'], 'duration_ms') }}
