select
    {{ to_int('circuitid') }} as circuit_id,
    {{ clean_text('circuitref') }} as circuit_ref,
    {{ clean_text('name') }} as circuit_name,
    {{ clean_text('location') }} as location,
    {{ clean_text('country') }} as country,
    {{ to_decimal('lat', 10, 6) }} as latitude,
    {{ to_decimal('lng', 10, 6) }} as longitude,
    {{ to_int('alt') }} as altitude_m,
    {{ clean_text('url') }} as url
from {{ source('ergast', 'circuits') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['circuit_id'], 'circuit_id') }}
