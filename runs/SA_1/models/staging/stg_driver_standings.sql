select
    driverstandingsid::int as driver_standings_id,
    raceid::int as race_id,
    driverid::int as driver_id,
    points::float as points,
    position::int as position,
    wins::int as wins
from {{ source('f1_raw', 'driver_standings') }}
