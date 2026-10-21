with source as (
    select * from {{ source('ergast', 'constructor_standings') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('constructorstandingsid') }}  as constructor_standing_id,
    {{ ergast_int('raceid') }}                  as race_id,
    {{ ergast_int('constructorid') }}           as constructor_id,
    {{ ergast_number('points') }}               as points,
    {{ ergast_int('position') }}                as position,
    {{ ergast_clean('positiontext') }}          as position_text,
    {{ ergast_int('wins') }}                    as wins
from source
