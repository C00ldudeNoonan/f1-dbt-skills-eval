select
    driverstandingsid::int as driver_standing_id,
    raceid::int as race_id,
    driverid::int as driver_id,
    points::number(10, 2) as points,
    position::int as championship_position,
    wins::int as wins
from {{ source('f1_raw', 'driver_standings') }}
