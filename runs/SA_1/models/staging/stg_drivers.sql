select
    driverid::int as driver_id,
    trim(driverref) as driver_ref,
    trim(forename) as forename,
    trim(surname) as surname,
    trim(forename) || ' ' || trim(surname) as full_name,
    {{ clean_text('code') }} as driver_code,
    {{ clean_text('number') }}::int as current_number,
    trim(nationality) as nationality,
    {{ clean_text('dob') }}::date as date_of_birth
from {{ source('f1_raw', 'drivers') }}
