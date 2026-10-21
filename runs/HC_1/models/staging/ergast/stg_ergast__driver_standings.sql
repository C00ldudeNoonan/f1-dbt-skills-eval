with source as (

    select * from {{ source('ergast', 'driver_standings') }}

)

select
    try_to_number(driverstandingsid) as driver_standings_id,
    try_to_number(raceid) as race_id,
    try_to_number(driverid) as driver_id,
    try_to_decimal(points, 6, 2) as points,
    try_to_number(position) as position,
    try_to_number(wins) as wins

from source
