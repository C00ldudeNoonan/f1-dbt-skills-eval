with source as (
    select * from {{ source('f1_raw', 'driver_standings') }}
)

select
    {{ to_integer('driverstandingsid') }} as driver_standings_id,
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('driverid') }} as driver_id,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ to_integer('position') }} as position,
    -- Numeric when ranked; 'D' marks a driver excluded from the championship
    -- (Michael Schumacher, 1997) and 'E' an excluded constructor (McLaren, 2007).
    {{ clean_text('positiontext') }} as position_text,
    {{ to_integer('wins') }} as wins
from source
{{ deduplicate('race_id, driver_id', 'driver_standings_id') }}
