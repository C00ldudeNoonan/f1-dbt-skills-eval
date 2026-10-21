select
    {{ to_int('driverstandingsid') }} as driver_standing_id,
    {{ to_int('raceid') }} as race_id,
    {{ to_int('driverid') }} as driver_id,
    {{ to_decimal('points', 8, 2) }} as points,
    -- position is the rank Ergast stores even for excluded drivers; position_text
    -- carries 'D' when a driver was excluded from the championship (Schumacher 1997).
    {{ to_int('position') }} as position,
    {{ clean_text('positiontext') }} as position_text,
    {{ to_int('wins') }} as wins
from {{ source('ergast', 'driver_standings') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'driver_id'], 'driver_standing_id') }}
