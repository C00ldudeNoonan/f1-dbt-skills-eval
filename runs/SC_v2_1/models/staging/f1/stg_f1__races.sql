select
    raceid::integer as race_id,
    year::integer as season,
    round::integer as round,
    circuitid::integer as circuit_id,
    trim(name) as race_name,
    {{ parse_raw_date('date') }} as race_date
from {{ source('f1_raw', 'races') }}
{{ dedupe(['race_id']) }}
