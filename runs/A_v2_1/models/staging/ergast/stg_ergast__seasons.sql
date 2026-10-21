select
    {{ to_int('year') }} as season,
    {{ clean_text('url') }} as url
from {{ source('ergast', 'seasons') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['season'], 'season') }}
