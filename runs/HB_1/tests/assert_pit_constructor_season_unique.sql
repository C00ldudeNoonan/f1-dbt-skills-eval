select
    season,
    constructor_id,
    count(*) as row_count
from {{ ref('mart_constructor_season_pit_stops') }}
group by season, constructor_id
having count(*) > 1
