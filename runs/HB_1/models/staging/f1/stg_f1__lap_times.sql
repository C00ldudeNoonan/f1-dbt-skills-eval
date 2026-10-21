with source as (

    select * from {{ source('f1_raw', 'lap_times') }}

)

select
    cast(raceid as int) as race_id,
    cast(driverid as int) as driver_id,
    cast(lap as int) as lap,
    cast(position as int) as position,
    {{ na_to_null('time') }} as lap_time_text,
    cast({{ na_to_null('milliseconds') }} as int) as lap_time_ms
from source
