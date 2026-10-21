-- The vendor's surrogate id is dropped: a re-delivered snapshot carries new ids for identical
-- rows. `select distinct` collapses the copies; conflicting rows fail the unique test on
-- (race_id, driver_id).
select distinct
    raceid::integer as race_id,
    driverid::integer as driver_id,
    {{ clean_text('points') }}::number(8, 2) as points,
    {{ clean_text('position') }}::integer as position,
    {{ clean_text('wins') }}::integer as wins
from {{ source('ergast', 'driver_standings') }}
