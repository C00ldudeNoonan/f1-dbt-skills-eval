select season, driver_id as k, 'driver' as kind from {{ ref('mart_driver_season_standings') }} group by 1, 2 having count(*) > 1
union all
select season, championship_position, 'position' from {{ ref('mart_driver_season_standings') }} group by 1, 2 having count(*) > 1
