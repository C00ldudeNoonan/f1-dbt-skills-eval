{#
  dim_drivers, version 1 — DEPRECATED (deprecation_date 2027-01-01).
  Kept for consumers that have not yet migrated to v2. It is a pure projection
  of v2 so the two can never disagree; delete this file (and its YAML entry)
  once the deprecation date passes.

  Built at the original relation name (dim_drivers) so existing direct-SQL
  consumers are unaffected.
#}

select
    driver_id,
    driver_ref,
    (first_name || ' ' || last_name)::varchar   as full_name,
    first_name                                  as forename,
    last_name                                   as surname,
    driver_code,
    current_number,
    nationality,
    date_of_birth,
    career_starts,
    career_wins,
    career_podiums,
    world_championships,
    career_points_scored,
    first_season,
    last_season,
    career_sprint_wins
from {{ ref('dim_drivers', v=2) }}
