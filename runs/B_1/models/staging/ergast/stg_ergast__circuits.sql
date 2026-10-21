with source as (
    select * from {{ source('ergast', 'circuits') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('circuitid') }}                     as circuit_id,
    {{ ergast_clean('circuitref') }}                  as circuit_ref,
    {{ ergast_clean('name') }}                        as circuit_name,
    {{ ergast_clean('location') }}                    as location,
    {{ ergast_clean('country') }}                     as country,
    cast({{ ergast_clean('lat') }} as float)          as latitude,
    cast({{ ergast_clean('lng') }} as float)          as longitude,
    cast({{ ergast_clean('alt') }} as integer)        as altitude_m,
    {{ ergast_clean('url') }}                         as wikipedia_url
from source
