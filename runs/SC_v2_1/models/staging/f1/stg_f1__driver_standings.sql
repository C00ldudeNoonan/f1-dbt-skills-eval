select
    driverstandingsid::integer as driver_standings_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    points::number(8, 2) as points,
    position::integer as championship_position,
    wins::integer as wins
from {{ source('f1_raw', 'driver_standings') }}
{{ dedupe(['race_id', 'driver_id'], ['driver_standings_id']) }}
