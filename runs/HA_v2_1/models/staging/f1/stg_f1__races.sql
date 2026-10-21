select
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('YEAR') }}::int as season,
    {{ clean_null('ROUND') }}::int as round,
    {{ clean_null('CIRCUITID') }}::int as circuit_id,
    {{ clean_null('NAME') }} as race_name,
    to_date({{ clean_null('DATE') }}, 'DD/MM/YYYY') as race_date
from ({{ dedupe_raw(source('f1_raw', 'RACES'), 'RACEID') }})
