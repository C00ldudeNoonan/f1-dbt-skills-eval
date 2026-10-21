select
    {{ clean_null('circuitid') }}::integer as circuit_id,
    {{ clean_null('circuitref') }} as circuit_ref,
    {{ clean_null('name') }} as circuit_name,
    {{ clean_null('location') }} as location,
    {{ clean_null('country') }} as country

from {{ source('f1_raw', 'circuits') }}
