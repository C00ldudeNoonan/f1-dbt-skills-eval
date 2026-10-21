select
    {{ clean_null('CONSTRUCTORSTANDINGSID') }}::int as constructor_standings_id,
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('CONSTRUCTORID') }}::int as constructor_id,
    {{ clean_null('POINTS') }}::decimal(6, 2) as points,
    {{ clean_null('POSITION') }}::int as position_number,
    {{ clean_null('POSITIONTEXT') }} as position_text,
    {{ clean_null('WINS') }}::int as wins
from ({{ dedupe_raw(source('f1_raw', 'CONSTRUCTOR_STANDINGS'), 'CONSTRUCTORSTANDINGSID') }})
