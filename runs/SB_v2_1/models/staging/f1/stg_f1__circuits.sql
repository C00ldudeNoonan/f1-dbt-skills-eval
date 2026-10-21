select
    {{ clean_int('circuitid') }} as circuit_id,
    {{ clean_raw('circuitref') }} as circuit_ref,
    {{ clean_raw('name') }} as circuit_name,
    {{ clean_raw('location') }} as location,
    {{ clean_raw('country') }} as country
from {{ source('f1_raw', 'circuits') }}
qualify row_number() over (partition by circuit_id order by circuit_id) = 1
