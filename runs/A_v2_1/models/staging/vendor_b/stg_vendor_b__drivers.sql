-- Vendor B drivers. FULL_NAME is 'SURNAME Forename' with the surname in
-- capitals (possibly several words, e.g. 'DE VRIES Nyck'): the surname is the
-- leading run of all-capital words, the forename is the rest.
with source as (

    select * from {{ source('vendor_b', 'vb_drivers') }}

),

parsed as (

    select
        {{ clean_text('driver_key') }} as driver_key,
        {{ clean_text('full_name') }} as full_name,
        regexp_substr({{ clean_text('full_name') }}, '^([^a-z]+)( |$)', 1, 1, 'e', 1) as surname_raw,
        {{ clean_text('abbreviation') }} as driver_code,
        racing_number::integer as racing_number
    from source

)

select
    driver_key,
    full_name,
    initcap(trim(surname_raw)) as surname,
    nullif(trim(substr(full_name, length(surname_raw) + 1)), '') as forename,
    driver_code,
    racing_number
from parsed
{{ dedupe_on(['driver_key'], 'driver_key') }}
