select
    {{ to_int('raceid') }} as race_id,
    {{ to_int('year') }} as season,
    {{ to_int('round') }} as round,
    {{ to_int('circuitid') }} as circuit_id,
    {{ clean_text('name') }} as race_name,
    {{ to_date('date') }} as race_date,
    {{ to_time('time') }} as race_time_utc,
    {{ to_date('sprint_date') }} as sprint_date,
    {{ clean_text('sprint_date') }} is not null as has_sprint,
    {{ clean_text('url') }} as url
from {{ source('ergast', 'races') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['race_id'], 'race_id') }}
