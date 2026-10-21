select drivers.driver_id, drivers.world_championships
from {{ ref('dim_drivers') }} as drivers
where drivers.world_championships <> (
    select count(*)
    from {{ ref('mart_driver_season_standings') }} as s
    where s.driver_id = drivers.driver_id
        and s.championship_position = 1
        and s.is_season_complete
)
