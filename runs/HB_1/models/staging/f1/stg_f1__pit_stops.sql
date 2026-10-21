with source as (

    select * from {{ source('f1_raw', 'pit_stops') }}

)

select
    cast(raceid as int) as race_id,
    cast(driverid as int) as driver_id,
    cast(stop as int) as stop_number,
    cast(lap as int) as lap,
    cast({{ na_to_null('milliseconds') }} as int) as duration_ms
from source
