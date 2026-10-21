select
    qualifyid::integer as qualify_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    constructorid::integer as constructor_id,
    position::integer as qualifying_position,
    {{ time_text_to_ms('q1') }} as q1_ms,
    {{ time_text_to_ms('q2') }} as q2_ms,
    {{ time_text_to_ms('q3') }} as q3_ms
from {{ source('f1_raw', 'qualifying') }}
{{ dedupe(['qualify_id']) }}
