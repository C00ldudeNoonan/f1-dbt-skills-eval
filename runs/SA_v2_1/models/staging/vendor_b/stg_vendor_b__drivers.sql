select distinct
    {{ clean_text('driver_key') }} as driver_key,
    {{ clean_text('full_name') }} as full_name,
    {{ clean_text('abbreviation') }} as driver_code,
    racing_number::integer as racing_number,
    {{ normalize_name(clean_text('full_name')) }} as name_key
from {{ source('vendor_b', 'vb_drivers') }}
