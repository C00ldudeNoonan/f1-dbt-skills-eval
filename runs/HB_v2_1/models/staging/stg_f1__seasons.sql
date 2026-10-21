select
    {{ clean_null('year') }}::integer as season,
    {{ clean_null('url') }} as season_url

from {{ source('f1_raw', 'seasons') }}
