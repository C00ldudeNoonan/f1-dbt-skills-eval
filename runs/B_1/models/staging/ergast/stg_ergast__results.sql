with source as (
    select * from {{ source('ergast', 'results') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('resultid') }}            as result_id,
    {{ ergast_int('raceid') }}              as race_id,
    {{ ergast_int('driverid') }}            as driver_id,
    {{ ergast_int('constructorid') }}       as constructor_id,
    {{ ergast_int('number') }}              as car_number,
    -- grid 0 means started from the pit lane (or did not start / qualify)
    {{ ergast_int('grid') }}                as grid,
    -- position is '\N' when not classified. Two rows (2005 Australian GP) have
    -- a null position but a numeric positionText and a "+n Laps" status, i.e.
    -- they were classified; fall back to positionText for those.
    coalesce(
        {{ ergast_int('position') }},
        iff(
            regexp_like({{ ergast_clean('positiontext') }}, '^[0-9]+$'),
            cast({{ ergast_clean('positiontext') }} as integer),
            null
        )
    )                                       as finish_position,
    -- R = retired, D = disqualified, E = excluded, W = withdrew,
    -- F = failed to qualify, N = not classified
    {{ ergast_clean('positiontext') }}      as position_text,
    {{ ergast_int('position_order') }}       as position_order,
    {{ ergast_number('points') }}           as points,
    {{ ergast_int('laps') }}                as laps,
    {{ ergast_clean('time') }}              as race_time_text,
    {{ ergast_int('milliseconds') }}        as race_time_ms,
    {{ ergast_int('fastestlap') }}          as fastest_lap_number,
    {{ ergast_int('rank') }}                as fastest_lap_rank,
    {{ lap_time_to_ms('fastestlaptime') }}  as fastest_lap_time_ms,
    cast({{ ergast_clean('fastestlapspeed') }} as number(7, 3)) as fastest_lap_speed_kph,
    {{ ergast_int('statusid') }}            as status_id
from source
