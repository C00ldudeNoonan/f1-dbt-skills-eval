with cleaned as (
    select
        {{ clean_int('year') }}     as season,
        {{ clean_text('url') }}     as wikipedia_url
    from {{ source('ergast', 'seasons') }}
)

select * from cleaned
{{ dedupe('season', 'season') }}
