-- Lap times use milliseconds as the source of truth. Red-flag laps are written
-- as h:mm:ss.sss in the TIME text column, so that text is not parsed here.

with source as (

    select * from {{ source('f1_raw', 'lap_times') }}

)

select
    raceid::integer as race_id,
    driverid::integer as driver_id,
    lap::integer as lap_number,
    position::integer as position,
    milliseconds::integer as lap_time_ms
from source
