with source as (
    select * from {{ source('ergast', 'circuits') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('circuitid') }}                       as circuit_id,
    {{ clean_text('circuitref') }}                  as circuit_ref,
    {{ clean_text('name') }}                        as circuit_name,
    {{ clean_text('location') }}                    as location,
    {{ clean_text('country') }}                     as country,
    try_to_double({{ clean_text('lat') }})          as latitude,
    try_to_double({{ clean_text('lng') }})          as longitude,
    {{ to_int('alt') }}                             as altitude_m,
    {{ clean_text('url') }}                         as wikipedia_url
from source
