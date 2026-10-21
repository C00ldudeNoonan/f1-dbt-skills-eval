select
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('year') }} as season,
    {{ clean_int('round') }} as round,
    {{ clean_int('circuitid') }} as circuit_id,
    {{ clean_raw('name') }} as race_name,
    {{ clean_date('date') }} as race_date,
    {{ clean_date('sprint_date') }} as sprint_date
from {{ source('f1_raw', 'races') }}
qualify row_number() over (partition by race_id order by race_id) = 1
