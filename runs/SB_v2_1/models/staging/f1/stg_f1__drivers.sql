select
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_raw('driverref') }} as driver_ref,
    {{ clean_int('number') }} as permanent_number,
    {{ clean_raw('code') }} as driver_code,
    {{ clean_raw('forename') }} as forename,
    {{ clean_raw('surname') }} as surname,
    {{ clean_raw('forename') }} || ' ' || {{ clean_raw('surname') }} as full_name,
    {{ clean_date('dob') }} as date_of_birth,
    {{ clean_raw('nationality') }} as nationality
from {{ source('f1_raw', 'drivers') }}
qualify row_number() over (partition by driver_id order by driver_id) = 1
