select
    {{ to_int('constructorresultsid') }} as constructor_result_id,
    {{ to_int('raceid') }} as race_id,
    {{ to_int('constructorid') }} as constructor_id,
    {{ to_decimal('points', 8, 2) }} as points,
    {{ clean_text('status') }} as status
from {{ source('ergast', 'constructor_results') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id', 'constructor_id'], 'constructor_result_id') }}
