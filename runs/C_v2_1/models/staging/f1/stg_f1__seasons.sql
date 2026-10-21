with source as (
    select * from {{ source('f1_raw', 'seasons') }}
)

select
    {{ to_integer('year') }} as season,
    {{ clean_text('url') }} as wikipedia_url
from source
{{ deduplicate('season', 'season') }}
