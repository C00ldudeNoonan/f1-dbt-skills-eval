with source as (
    select * from {{ source('ergast', 'driver_standings') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('driverstandingsid') }}   as driver_standing_id,
    {{ ergast_int('raceid') }}              as race_id,
    {{ ergast_int('driverid') }}            as driver_id,
    {{ ergast_number('points') }}           as points,
    -- position is always populated in the source, even for the one excluded
    -- driver (positionText = 'D'), who is placed last.
    {{ ergast_int('position') }}            as position,
    {{ ergast_clean('positiontext') }}      as position_text,
    {{ ergast_clean('positiontext') }} = 'D' as is_excluded_from_championship,
    {{ ergast_int('wins') }}                as wins
from source
