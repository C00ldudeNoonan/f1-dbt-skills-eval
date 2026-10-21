-- Vendor B drivers. `name_key` is an order- and accent-insensitive key ('HULKENBERG Nico' ~ 'Nico Hülkenberg').
select
    {{ clean_raw('driver_key') }} as driver_key,
    {{ clean_raw('full_name') }} as full_name,
    {{ name_key(clean_raw('full_name')) }} as name_key,
    upper({{ clean_raw('abbreviation') }}) as abbreviation,
    {{ clean_int('racing_number') }} as racing_number
from {{ source('f1_raw', 'vb_drivers') }}
qualify row_number() over (partition by driver_key order by driver_key) = 1
