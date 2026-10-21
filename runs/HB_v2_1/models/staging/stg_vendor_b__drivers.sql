select
    {{ clean_null('driver_key') }} as driver_key,
    {{ clean_null('full_name') }} as full_name,
    -- Vendor B writes names as SURNAME Given. The given name is the last word; the surname is the rest.
    regexp_substr(trim({{ clean_null('full_name') }}), '^(.*) [^ ]+$', 1, 1, 'e', 1) as vb_surname,
    regexp_substr(trim({{ clean_null('full_name') }}), '[^ ]+$') as vb_given_name,
    {{ clean_null('abbreviation') }} as abbreviation,
    {{ clean_null('racing_number') }}::integer as racing_number

from {{ source('vendor_b', 'vb_drivers') }}
