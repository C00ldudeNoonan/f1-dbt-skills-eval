select distinct
    qualifyid::integer as qualify_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    constructorid::integer as constructor_id,
    {{ clean_text('position') }}::integer as qualifying_position,
    {{ lap_time_to_ms('q1') }} as q1_ms,
    {{ lap_time_to_ms('q2') }} as q2_ms,
    {{ lap_time_to_ms('q3') }} as q3_ms
from {{ source('ergast', 'qualifying') }}
