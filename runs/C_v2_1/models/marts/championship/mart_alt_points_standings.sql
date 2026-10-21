-- What-if standings under one points system: the current system by default.
-- Select another with --vars '{alt_points_system: fia_1991}', or query
-- mart_alt_points_standings_by_system to compare systems.

select
    season,
    driver_id,
    points_system,
    alt_points,
    alt_position,
    alt_wins
from {{ ref('mart_alt_points_standings_by_system') }}
where points_system = '{{ var("alt_points_system", "fia_2010") }}'
