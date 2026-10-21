{#-
  What-if standings under a single points system (var alt_points_system,
  default fia_2010: 25-18-15-12-10-8-6-4-2-1). One row per driver per season.
  See mart_alt_points_standings_by_system for the scoring rules and for every
  system side by side.
-#}
select
    season,
    driver_id,
    alt_points,
    alt_position,
    alt_wins,
    points_system
from {{ ref('mart_alt_points_standings_by_system') }}
where points_system = '{{ var("alt_points_system") }}'
