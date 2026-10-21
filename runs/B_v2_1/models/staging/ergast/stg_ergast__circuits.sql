with cleaned as (
    select
        {{ clean_int('circuitid') }}                as circuit_id,
        {{ clean_text('circuitref') }}              as circuit_ref,
        {{ clean_text('name') }}                    as circuit_name,
        {{ clean_text('location') }}                as location,
        {{ clean_text('country') }}                 as country,
        try_to_double({{ clean_text('lat') }})      as latitude,
        try_to_double({{ clean_text('lng') }})      as longitude,
        {{ clean_int('alt') }}                      as altitude_m,
        {{ clean_text('url') }}                     as wikipedia_url
    from {{ source('ergast', 'circuits') }}
)

select * from cleaned
{{ dedupe('circuit_id', 'circuit_id') }}
