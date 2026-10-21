select distinct
    driverid::integer as driver_id,
    {{ clean_text('driverref') }} as driver_ref,
    {{ clean_text('number') }}::integer as driver_number,
    {{ clean_text('code') }} as driver_code,
    {{ clean_text('forename') }} as forename,
    {{ clean_text('surname') }} as surname,
    try_to_date({{ clean_text('dob') }}) as date_of_birth,
    {{ clean_text('nationality') }} as nationality
from {{ source('ergast', 'drivers') }}
