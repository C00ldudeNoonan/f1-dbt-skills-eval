-- Driver-season standings under the default alternative points system
-- (var `default_points_system`). Other systems: mart_alt_points_standings_all_systems.
select
    points_system,
    season,
    driver_id,
    alt_points,
    alt_position
from {{ ref('mart_alt_points_standings_all_systems') }}
where points_system = '{{ var("default_points_system") }}'
