select
    {{ to_int('qualifyid') }} as qualify_id,
    {{ to_int('raceid') }} as race_id,
    {{ to_int('driverid') }} as driver_id,
    {{ to_int('constructorid') }} as constructor_id,
    {{ to_int('number') }} as car_number,
    {{ to_int('position') }} as qualifying_position,
    -- Missing times appear both as \N and as empty strings.
    {{ duration_to_ms('q1') }} as q1_ms,
    {{ duration_to_ms('q2') }} as q2_ms,
    {{ duration_to_ms('q3') }} as q3_ms
from {{ source('ergast', 'qualifying') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'driver_id'], 'qualify_id') }}
