with source as (
    select * from {{ source('vendor_b', 'vb_drivers') }}
),

parsed as (
    select
        trim(driver_key)                                                as driver_key,
        trim(full_name)                                                 as full_name,
        -- 'DE VRIES Nyck': the forename starts at the first word containing a lowercase letter.
        trim(regexp_substr(trim(full_name), '(^| )([^ ]*[a-z].*)$', 1, 1, 'e', 2)) as forename,
        trim(abbreviation)                                              as driver_code,
        racing_number::integer                                          as racing_number
    from source
)

select
    driver_key,
    full_name,
    forename,
    trim(left(full_name, length(full_name) - coalesce(length(forename), 0)))  as surname,
    driver_code,
    racing_number
from parsed
{{ dedupe('driver_key', 'driver_key') }}
