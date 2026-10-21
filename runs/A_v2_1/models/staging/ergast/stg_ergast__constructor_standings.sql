select
    {{ to_int('constructorstandingsid') }} as constructor_standing_id,
    {{ to_int('raceid') }} as race_id,
    {{ to_int('constructorid') }} as constructor_id,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ to_int('position') }} as position,
    {{ clean_text('positiontext') }} as position_text,
    {{ to_int('wins') }} as wins
from {{ source('ergast', 'constructor_standings') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'constructor_id'], 'constructor_standing_id') }}
