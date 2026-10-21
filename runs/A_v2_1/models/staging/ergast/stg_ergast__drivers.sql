select
    {{ to_int('driverid') }} as driver_id,
    {{ clean_text('driverref') }} as driver_ref,
    {{ to_int('number') }} as permanent_number,
    {{ clean_text('code') }} as driver_code,
    {{ clean_text('forename') }} as forename,
    {{ clean_text('surname') }} as surname,
    {{ clean_text('forename') }} || ' ' || {{ clean_text('surname') }} as full_name,
    {{ to_date('dob') }} as date_of_birth,
    {{ clean_text('nationality') }} as nationality,
    {{ clean_text('url') }} as url
from {{ source('ergast', 'drivers') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['driver_id'], 'driver_id') }}
