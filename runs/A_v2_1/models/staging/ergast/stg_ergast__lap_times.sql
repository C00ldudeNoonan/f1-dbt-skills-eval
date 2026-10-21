select
    {{ to_int('raceid') }} as race_id,
    {{ to_int('driverid') }} as driver_id,
    {{ to_int('lap') }} as lap,
    {{ to_int('position') }} as position,
    {{ clean_text('time') }} as lap_time_text,
    {{ to_int('milliseconds') }} as lap_time_ms
from {{ source('ergast', 'lap_times') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'driver_id', 'lap'], 'lap_time_ms') }}
