select
    {{ clean_null('YEAR') }}::int as season,
    {{ clean_null('URL') }} as season_url
from ({{ dedupe_raw(source('f1_raw', 'SEASONS'), 'YEAR') }})
