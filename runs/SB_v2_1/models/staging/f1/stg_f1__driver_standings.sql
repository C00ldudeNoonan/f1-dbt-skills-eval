select
    {{ clean_int('driverstandingsid') }} as driver_standings_id,
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_decimal('points') }} as points,
    {{ clean_int('position') }} as position,
    {{ clean_int('wins') }} as wins
from {{ source('f1_raw', 'driver_standings') }}
qualify row_number() over (partition by race_id, driver_id order by driver_standings_id) = 1
