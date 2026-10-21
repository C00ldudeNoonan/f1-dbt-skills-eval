with source as (
    select * from {{ source('ergast', 'sprint_results') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('resultid') }}            as sprint_result_id,
    {{ ergast_int('raceid') }}              as race_id,
    {{ ergast_int('driverid') }}            as driver_id,
    {{ ergast_int('constructorid') }}       as constructor_id,
    {{ ergast_int('number') }}              as car_number,
    {{ ergast_int('grid') }}                as grid,
    {{ ergast_int('position') }}            as finish_position,
    {{ ergast_clean('positiontext') }}      as position_text,
    {{ ergast_int('position_order') }}       as position_order,
    {{ ergast_number('points') }}           as points,
    {{ ergast_int('laps') }}                as laps,
    {{ ergast_clean('time') }}              as race_time_text,
    {{ ergast_int('milliseconds') }}        as race_time_ms,
    {{ ergast_int('fastestlap') }}          as fastest_lap_number,
    {{ lap_time_to_ms('fastestlaptime') }}  as fastest_lap_time_ms,
    {{ ergast_int('statusid') }}            as status_id
from source
