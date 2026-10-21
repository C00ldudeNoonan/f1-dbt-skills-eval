select
    points_system,
    season,
    alt_position,
    count(*) as drivers

from {{ ref('mart_alt_points_standings') }}
group by points_system, season, alt_position
having count(*) > 1
