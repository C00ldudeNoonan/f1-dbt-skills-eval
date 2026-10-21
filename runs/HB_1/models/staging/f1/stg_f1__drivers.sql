with source as (

    select * from {{ source('f1_raw', 'drivers') }}

)

select
    cast(driverid as int) as driver_id,
    {{ na_to_null('driverref') }} as driver_ref,
    cast({{ na_to_null('number') }} as int) as driver_number,
    {{ na_to_null('code') }} as driver_code,
    {{ na_to_null('forename') }} as forename,
    {{ na_to_null('surname') }} as surname,
    cast({{ na_to_null('dob') }} as date) as date_of_birth,
    {{ na_to_null('nationality') }} as nationality
from source
