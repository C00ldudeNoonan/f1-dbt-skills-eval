select
    {{ clean_null('DRIVERID') }}::int as driver_id,
    {{ clean_null('DRIVERREF') }} as driver_ref,
    {{ clean_null('NUMBER') }}::int as permanent_number,
    {{ clean_null('CODE') }} as driver_code,
    {{ clean_null('FORENAME') }} as forename,
    {{ clean_null('SURNAME') }} as surname,
    {{ clean_null('DOB') }}::date as date_of_birth,
    {{ clean_null('NATIONALITY') }} as nationality
from ({{ dedupe_raw(source('f1_raw', 'DRIVERS'), 'DRIVERID') }})
