{#
  Grand Prix results. Sprint results live in stg_ergast__sprint_results and are
  deliberately kept separate.

  finish_position is derived from positionText rather than position: the raw
  `position` column is \N for two classified finishers (2005 Australian GP,
  positionText 11 and 14). positionText is numeric exactly when the driver was
  classified; otherwise it is a code (R retired, D disqualified, E excluded,
  W withdrew, F failed to qualify, N not classified).
#}

with source as (
    select * from {{ source('ergast', 'results') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('resultid') }}            as result_id,
    {{ to_int('raceid') }}              as race_id,
    {{ to_int('driverid') }}            as driver_id,
    {{ to_int('constructorid') }}       as constructor_id,
    {{ to_int('number') }}              as car_number,
    {{ to_int('grid') }}                as grid,
    {{ clean_text('positiontext') }}    as position_text,
    case
        when {{ clean_text('positiontext') }} regexp '^[0-9]+$'
            then {{ to_int('positiontext') }}
    end                                 as finish_position,
    {{ to_int('position_order') }}       as position_order,
    {{ to_decimal('points') }}          as points,
    {{ to_int('laps') }}                as laps,
    {{ clean_text('time') }}            as race_time_text,
    {{ to_int('milliseconds') }}        as race_time_ms,
    {{ to_int('fastestlap') }}          as fastest_lap_number,
    {{ to_int('rank') }}                as fastest_lap_rank,
    {{ clean_text('fastestlaptime') }}  as fastest_lap_time_text,
    {{ lap_time_to_ms('fastestlaptime') }} as fastest_lap_time_ms,
    try_to_double({{ clean_text('fastestlapspeed') }}) as fastest_lap_speed_kph,
    {{ to_int('statusid') }}            as status_id
from source
