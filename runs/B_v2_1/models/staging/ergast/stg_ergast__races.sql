with cleaned as (
    select
        {{ clean_int('raceid') }}                       as race_id,
        {{ clean_int('year') }}                         as season,
        {{ clean_int('round') }}                        as round,
        {{ clean_int('circuitid') }}                    as circuit_id,
        {{ clean_text('name') }}                        as race_name,
        {{ parse_date('date') }}           as race_date,
        try_to_time({{ clean_text('time') }})           as race_time_utc,
        {{ parse_date('quali_date') }}     as qualifying_date,
        {{ parse_date('sprint_date') }}    as sprint_date,
        {{ clean_text('sprint_date') }} is not null     as has_sprint,
        {{ clean_text('url') }}                         as wikipedia_url
    from {{ source('ergast', 'races') }}
)

select * from cleaned
{{ dedupe('race_id', 'race_id') }}
