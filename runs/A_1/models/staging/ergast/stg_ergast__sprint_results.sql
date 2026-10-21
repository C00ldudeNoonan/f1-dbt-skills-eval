with source as (
    select * from {{ source('ergast', 'sprint_results') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('resultid') }}            as sprint_result_id,
    {{ to_int('raceid') }}              as race_id,
    {{ to_int('driverid') }}            as driver_id,
    {{ to_int('constructorid') }}       as constructor_id,
    {{ to_int('grid') }}                as grid,
    {{ clean_text('positiontext') }}    as position_text,
    case
        when {{ clean_text('positiontext') }} regexp '^[0-9]+$'
            then {{ to_int('positiontext') }}
    end                                 as finish_position,
    {{ to_int('position_order') }}       as position_order,
    {{ to_decimal('points') }}          as points,
    {{ to_int('laps') }}                as laps,
    {{ to_int('milliseconds') }}        as race_time_ms,
    {{ lap_time_to_ms('fastestlaptime') }} as fastest_lap_time_ms,
    {{ to_int('statusid') }}            as status_id
from source
