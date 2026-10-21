-- World championships per driver. A title only counts once its season is complete
-- (every calendar race has results), so an in-progress season never adds one.

select
    driver_id,
    count(*) as world_championships
from {{ ref('mart_driver_season_standings') }}
where is_season_complete
    and championship_position = 1
group by driver_id
