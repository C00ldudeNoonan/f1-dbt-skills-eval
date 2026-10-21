with source as (

    select * from {{ source('f1_raw', 'pit_stops') }}

)

select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    stop::integer as stop_number,
    lap::integer as lap_number,
    milliseconds::integer as pit_stop_duration_ms
from source
