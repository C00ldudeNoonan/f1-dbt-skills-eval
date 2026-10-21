with source as (
    select * from {{ source('ergast', 'races') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('raceid') }}          as race_id,
    {{ ergast_int('year') }}            as season,
    {{ ergast_int('round') }}           as round,
    {{ ergast_int('circuitid') }}       as circuit_id,
    {{ ergast_clean('name') }}          as race_name,
    {{ ergast_date('date') }}           as race_date,
    {{ ergast_clean('time') }}          as race_start_time_utc,
    {{ ergast_date('fp1_date') }}       as fp1_date,
    {{ ergast_date('fp2_date') }}       as fp2_date,
    {{ ergast_date('fp3_date') }}       as fp3_date,
    {{ ergast_date('quali_date') }}     as qualifying_date,
    {{ ergast_date('sprint_date') }}    as sprint_date,
    {{ ergast_clean('url') }}           as wikipedia_url
from source
