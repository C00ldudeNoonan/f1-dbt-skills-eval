with source as (
    select * from {{ source('ergast', 'drivers') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('driverid') }}            as driver_id,
    {{ clean_text('driverref') }}       as driver_ref,
    {{ to_int('number') }}              as permanent_number,
    {{ clean_text('code') }}            as driver_code,
    {{ clean_text('forename') }}        as forename,
    {{ clean_text('surname') }}         as surname,
    {{ clean_text('forename') }} || ' ' || {{ clean_text('surname') }} as full_name,
    {{ to_date('dob') }}                as date_of_birth,
    {{ clean_text('nationality') }}     as nationality,
    {{ clean_text('url') }}             as wikipedia_url
from source
