select
    {{ clean_int('qualifyid') }} as qualify_id,
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_int('constructorid') }} as constructor_id,
    {{ clean_int('position') }} as position,
    {{ lap_time_to_ms('q1') }} as q1_ms,
    {{ lap_time_to_ms('q2') }} as q2_ms,
    {{ lap_time_to_ms('q3') }} as q3_ms
from {{ source('f1_raw', 'qualifying') }}
qualify row_number() over (partition by qualify_id order by qualify_id) = 1
