with source as (
    select * from {{ source('ergast', 'races') }}
)

-- distinct: collapse rows that are identical once cleaned (e.g. a vendor re-sending
-- a row with stray whitespace). Conflicting duplicates survive and fail the
-- uniqueness test on this model, blocking everything downstream.
select distinct
    {{ to_int('raceid') }}              as race_id,
    {{ to_int('year') }}                as season,
    {{ to_int('round') }}               as round,
    {{ to_int('circuitid') }}           as circuit_id,
    {{ clean_text('name') }}            as race_name,
    {{ to_date('date') }}               as race_date,
    try_to_time({{ clean_text('time') }})        as race_start_time_utc,
    {{ to_date('sprint_date') }}        as sprint_date,
    {{ to_date('sprint_date') }} is not null     as has_sprint,
    {{ clean_text('url') }}             as wikipedia_url
from source
