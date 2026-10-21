-- Vendor B drivers. FULL_NAME is 'SURNAME Forename' with the surname in
-- capitals (it can be several words, e.g. 'DE VRIES Nyck') and no accents.

with source as (
    select * from {{ source('f1_raw', 'vb_drivers') }}
),

cleaned as (
    select
        {{ clean_text('driver_key') }} as driver_key,
        {{ clean_text('full_name') }} as full_name,
        {{ clean_text('abbreviation') }} as driver_code,
        racing_number
    from source
)

select
    driver_key,
    full_name,
    -- Surname: everything before the first word containing a lowercase letter.
    trim(regexp_replace(full_name, '\\s+\\S*[a-z].*$', '')) as surname,
    trim(regexp_substr(full_name, '\\s\\S*[a-z].*$')) as forename,
    driver_code,
    racing_number
from cleaned
{{ deduplicate('driver_key', 'driver_key') }}
