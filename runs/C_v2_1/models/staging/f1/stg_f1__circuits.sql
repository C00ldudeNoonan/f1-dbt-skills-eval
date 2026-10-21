with source as (
    select * from {{ source('f1_raw', 'circuits') }}
)

select
    {{ to_integer('circuitid') }} as circuit_id,
    {{ clean_text('circuitref') }} as circuit_ref,
    {{ clean_text('name') }} as circuit_name,
    {{ clean_text('location') }} as location,
    {{ clean_text('country') }} as country,
    {{ to_decimal('lat', 10, 6) }} as latitude,
    {{ to_decimal('lng', 10, 6) }} as longitude,
    {{ to_integer('alt') }} as altitude_m,
    {{ clean_text('url') }} as wikipedia_url
from source
{{ deduplicate('circuit_id', 'circuit_id') }}
