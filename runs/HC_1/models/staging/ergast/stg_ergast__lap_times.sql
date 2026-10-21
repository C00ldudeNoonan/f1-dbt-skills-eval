with source as (

    select * from {{ source('ergast', 'lap_times') }}

)

select
    try_to_number(raceid) as race_id,
    try_to_number(driverid) as driver_id,
    try_to_number(lap) as lap,
    try_to_number({{ null_if_sentinel('position') }}) as position,
    try_to_number(milliseconds) as lap_time_ms

from source
