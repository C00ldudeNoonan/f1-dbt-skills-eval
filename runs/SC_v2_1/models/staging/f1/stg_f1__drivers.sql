select
    driverid::integer as driver_id,
    trim(driverref) as driver_ref,
    trim(forename) as first_name,
    trim(surname) as last_name,
    trim(forename) || ' ' || trim(surname) as full_name,
    {{ clean_raw('code') }} as driver_code,
    try_to_number({{ clean_raw('number') }})::integer as current_number,
    {{ clean_raw('nationality') }} as nationality,
    {{ parse_raw_date('dob') }} as date_of_birth
from {{ source('f1_raw', 'drivers') }}
{{ dedupe(['driver_id']) }}
