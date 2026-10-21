with source as (
    select * from {{ source('ergast', 'drivers') }}
),

renamed as (
    select
        {{ ergast_int('driverid') }}        as driver_id,
        {{ ergast_clean('driverref') }}     as driver_ref,
        {{ ergast_int('number') }}          as permanent_number,
        {{ ergast_clean('code') }}          as driver_code,
        {{ ergast_clean('forename') }}      as forename,
        {{ ergast_clean('surname') }}       as surname,
        {{ ergast_date('dob') }}            as date_of_birth,
        {{ ergast_clean('nationality') }}   as nationality_raw,
        {{ ergast_clean('url') }}           as wikipedia_url
    from source
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    driver_id,
    driver_ref,
    permanent_number,
    driver_code,
    forename,
    surname,
    forename || ' ' || surname as full_name,
    date_of_birth,
    -- The source spells one Argentine driver's nationality 'Argentinian '
    -- (with trailing space); standardise on the spelling used everywhere else.
    case nationality_raw
        when 'Argentinian' then 'Argentine'
        else nationality_raw
    end as nationality,
    wikipedia_url
from renamed
