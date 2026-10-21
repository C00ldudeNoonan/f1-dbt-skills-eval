with source as (

    select * from {{ source('ergast', 'drivers') }}

)

select
    try_to_number(driverid) as driver_id,
    driverref as driver_ref,
    try_to_number({{ null_if_sentinel('number') }}) as driver_number,
    {{ null_if_sentinel('code') }} as driver_code,
    trim(forename) as forename,
    trim(surname) as surname,
    try_to_date(dob) as date_of_birth,
    nationality

from source
