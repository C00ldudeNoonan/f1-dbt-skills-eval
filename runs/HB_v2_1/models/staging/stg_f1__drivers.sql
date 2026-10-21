select
    {{ clean_null('driverid') }}::integer as driver_id,
    {{ clean_null('driverref') }} as driver_ref,
    {{ clean_null('number') }}::integer as driver_number,
    {{ clean_null('code') }} as driver_code,
    {{ clean_null('forename') }} as forename,
    {{ clean_null('surname') }} as surname,
    {{ clean_null('dob') }}::date as date_of_birth,
    {{ clean_null('nationality') }} as nationality

from {{ source('f1_raw', 'drivers') }}
