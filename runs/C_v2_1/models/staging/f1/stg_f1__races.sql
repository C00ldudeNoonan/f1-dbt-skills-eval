with source as (
    select * from {{ source('f1_raw', 'races') }}
)

select
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('year') }} as season,
    {{ to_integer('round') }} as round,
    {{ to_integer('circuitid') }} as circuit_id,
    {{ clean_text('name') }} as race_name,
    -- The vendor sends the race date as DD/MM/YYYY (since the October 2026
    -- pipeline migration); the session dates below are still ISO.
    try_to_date({{ clean_text('date') }}, 'DD/MM/YYYY') as race_date,
    try_to_time({{ clean_text('time') }}) as race_time_utc,
    try_to_date({{ clean_text('fp1_date') }}, 'YYYY-MM-DD') as fp1_date,
    try_to_time({{ clean_text('fp1_time') }}) as fp1_time_utc,
    try_to_date({{ clean_text('fp2_date') }}, 'YYYY-MM-DD') as fp2_date,
    try_to_time({{ clean_text('fp2_time') }}) as fp2_time_utc,
    try_to_date({{ clean_text('fp3_date') }}, 'YYYY-MM-DD') as fp3_date,
    try_to_time({{ clean_text('fp3_time') }}) as fp3_time_utc,
    try_to_date({{ clean_text('quali_date') }}, 'YYYY-MM-DD') as qualifying_date,
    try_to_time({{ clean_text('quali_time') }}) as qualifying_time_utc,
    try_to_date({{ clean_text('sprint_date') }}, 'YYYY-MM-DD') as sprint_date,
    try_to_time({{ clean_text('sprint_time') }}) as sprint_time_utc,
    {{ clean_text('sprint_date') }} is not null as has_sprint,
    {{ clean_text('url') }} as wikipedia_url
from source
{{ deduplicate('race_id', 'race_id') }}
