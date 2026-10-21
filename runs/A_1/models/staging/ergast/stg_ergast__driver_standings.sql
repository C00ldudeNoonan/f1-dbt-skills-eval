{#
  Official standings after each race. position_text is 'D' for a driver
  excluded from the championship (Michael Schumacher, 1997); Ergast still gives
  such rows a numeric `position` at the bottom of the table, so we expose
  championship_position as null for them.
#}

with source as (
    select * from {{ source('ergast', 'driver_standings') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('driverstandingsid') }}   as driver_standings_id,
    {{ to_int('raceid') }}              as race_id,
    {{ to_int('driverid') }}            as driver_id,
    {{ to_decimal('points') }}          as points,
    {{ clean_text('positiontext') }}    as position_text,
    case
        when {{ clean_text('positiontext') }} regexp '^[0-9]+$'
            then {{ to_int('position') }}
    end                                 as championship_position,
    {{ to_int('wins') }}                as wins
from source
