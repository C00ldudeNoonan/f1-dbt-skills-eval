select
    driverid::int as driver_id,
    trim(driverref) as driver_ref,
    {{ clean_null('number') }}::int as driver_number,
    {{ clean_null('code') }} as driver_code,
    trim({{ clean_null('forename') }}) as forename,
    trim({{ clean_null('surname') }}) as surname,
    trim({{ clean_null('nationality') }}) as nationality,
    {{ clean_null('dob') }}::date as date_of_birth
from {{ source('f1_raw', 'drivers') }}
-- Exact duplicate rows in the raw dimension would fan out every join to it, so keep one row per key.
-- Rows that share a key but differ are caught by the source_no_conflicting_duplicates test.
qualify row_number() over (partition by driver_id order by driver_ref, forename, surname, date_of_birth) = 1
