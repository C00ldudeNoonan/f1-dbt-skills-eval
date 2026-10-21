with cleaned as (
    select
        {{ clean_int('constructorid') }}    as constructor_id,
        {{ clean_text('constructorref') }}  as constructor_ref,
        {{ clean_text('name') }}            as constructor_name,
        {{ clean_text('nationality') }}     as nationality,
        {{ clean_text('url') }}             as wikipedia_url
    from {{ source('ergast', 'constructors') }}
)

select * from cleaned
{{ dedupe('constructor_id', 'constructor_id') }}
