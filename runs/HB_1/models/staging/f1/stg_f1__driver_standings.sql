with source as (

    select * from {{ source('f1_raw', 'driver_standings') }}

)

select
    cast(driverstandingsid as int) as driver_standings_id,
    cast(raceid as int) as race_id,
    cast(driverid as int) as driver_id,
    cast(points as decimal(6, 2)) as points,
    cast(position as int) as championship_position,
    cast(wins as int) as wins
from source
