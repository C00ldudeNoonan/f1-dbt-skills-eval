with source as (

    select * from {{ source('f1_raw', 'driver_standings') }}

)

select
    driverstandingsid::integer as driver_standings_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    points::number(6, 2) as points,
    position::integer as championship_position,
    positiontext as position_text,
    wins::integer as wins
from source
