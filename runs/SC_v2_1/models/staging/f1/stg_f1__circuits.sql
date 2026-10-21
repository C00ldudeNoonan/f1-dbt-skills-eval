select
    circuitid::integer as circuit_id,
    trim(name) as circuit_name,
    {{ clean_raw('location') }} as location,
    {{ clean_raw('country') }} as country
from {{ source('f1_raw', 'circuits') }}
{{ dedupe(['circuit_id']) }}
