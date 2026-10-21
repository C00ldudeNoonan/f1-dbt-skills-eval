{#
    Vendor B drivers. Names arrive as "SURNAME Given" with the surname in capitals, so the surname is the leading run
    of capitalised words and the rest is the given name. Matching to our drivers happens in dim_driver_crosswalk.
#}
with parsed as (

    select
        trim(DRIVER_KEY) as driver_key,
        trim(FULL_NAME) as full_name,
        trim(regexp_substr(trim(FULL_NAME), '^[A-Z][A-Z\\-]*( [A-Z][A-Z\\-]*)*( |$)')) as surname,
        upper(trim(ABBREVIATION)) as abbreviation,
        RACING_NUMBER::integer as racing_number
    from {{ source('vendor_b', 'VB_DRIVERS') }}

)

select
    driver_key,
    full_name,
    surname,
    trim(substr(full_name, length(surname) + 1)) as given_name,
    abbreviation,
    racing_number
from parsed
