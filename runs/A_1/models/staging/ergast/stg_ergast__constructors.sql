with source as (
    select * from {{ source('ergast', 'constructors') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('constructorid') }}       as constructor_id,
    {{ clean_text('constructorref') }}  as constructor_ref,
    {{ clean_text('name') }}            as constructor_name,
    {{ clean_text('nationality') }}     as nationality,
    {{ clean_text('url') }}             as wikipedia_url
from source
