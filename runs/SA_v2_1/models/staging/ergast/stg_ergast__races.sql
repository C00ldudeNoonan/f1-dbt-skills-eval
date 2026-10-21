select distinct
    raceid::integer as race_id,
    year::integer as season,
    round::integer as round,
    circuitid::integer as circuit_id,
    {{ clean_text('name') }} as race_name,
    try_to_date({{ clean_text('date') }}, 'DD/MM/YYYY') as race_date
from {{ source('ergast', 'races') }}
