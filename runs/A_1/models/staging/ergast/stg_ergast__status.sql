with source as (
    select * from {{ source('ergast', 'status') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('statusid') }}    as status_id,
    {{ clean_text('status') }}  as status
from source
