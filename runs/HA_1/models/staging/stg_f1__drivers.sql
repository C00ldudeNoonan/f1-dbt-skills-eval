with source as (

    select * from {{ source('f1_raw', 'drivers') }}

)

select
    driverid::integer as driver_id,
    driverref as driver_ref,
    {{ null_marker('code') }} as driver_code,
    {{ null_marker('number') }}::integer as permanent_number,
    forename as first_name,
    surname as last_name,
    {{ null_marker('dob') }}::date as date_of_birth,
    nationality
from source
