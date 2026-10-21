with source as (

    select * from {{ source('ergast', 'pit_stops') }}

)

select
    try_to_number(raceid) as race_id,
    try_to_number(driverid) as driver_id,
    try_to_number(stop) as stop_number,
    try_to_number(lap) as lap,
    try_to_number(milliseconds) as duration_ms

from source
