select
    {{ null_if_sentinel('DRIVERID') }}::integer as driver_id,
    {{ null_if_sentinel('DRIVERREF') }} as driver_ref,
    {{ null_if_sentinel('NUMBER') }}::integer as driver_number,
    {{ null_if_sentinel('CODE') }} as driver_code,
    {{ null_if_sentinel('FORENAME') }} as forename,
    {{ null_if_sentinel('SURNAME') }} as surname,
    {{ null_if_sentinel('DOB') }}::date as date_of_birth,
    {{ null_if_sentinel('NATIONALITY') }} as nationality
from {{ source('f1_raw', 'DRIVERS') }}
