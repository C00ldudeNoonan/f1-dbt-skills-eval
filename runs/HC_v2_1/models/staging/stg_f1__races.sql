select
    {{ null_if_sentinel('RACEID') }}::integer as race_id,
    {{ null_if_sentinel('YEAR') }}::integer as season,
    {{ null_if_sentinel('ROUND') }}::integer as round,
    {{ null_if_sentinel('CIRCUITID') }}::integer as circuit_id,
    {{ null_if_sentinel('NAME') }} as race_name,
    {{ parse_race_date(null_if_sentinel('DATE')) }} as race_date,
    {{ parse_race_date(null_if_sentinel('SPRINT_DATE')) }} as sprint_date,
    {{ null_if_sentinel('TIME') }}::time as race_start_time
from {{ source('f1_raw', 'RACES') }}
