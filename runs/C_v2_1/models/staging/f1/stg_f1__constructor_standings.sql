with source as (
    select * from {{ source('f1_raw', 'constructor_standings') }}
)

select
    {{ to_integer('constructorstandingsid') }} as constructor_standings_id,
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('constructorid') }} as constructor_id,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ to_integer('position') }} as position,
    -- Numeric when ranked; 'D' marks a driver excluded from the championship
    -- (Michael Schumacher, 1997) and 'E' an excluded constructor (McLaren, 2007).
    {{ clean_text('positiontext') }} as position_text,
    {{ to_integer('wins') }} as wins
from source
{{ deduplicate('race_id, constructor_id', 'constructor_standings_id') }}
