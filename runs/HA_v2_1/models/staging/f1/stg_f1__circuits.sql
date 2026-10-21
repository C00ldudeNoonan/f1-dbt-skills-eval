select
    {{ clean_null('CIRCUITID') }}::int as circuit_id,
    {{ clean_null('CIRCUITREF') }} as circuit_ref,
    {{ clean_null('NAME') }} as circuit_name,
    {{ clean_null('LOCATION') }} as location,
    {{ clean_null('COUNTRY') }} as country,
    {{ clean_null('LAT') }}::float as latitude,
    {{ clean_null('LNG') }}::float as longitude,
    {{ clean_null('ALT') }}::int as altitude_m
from ({{ dedupe_raw(source('f1_raw', 'CIRCUITS'), 'CIRCUITID') }})
