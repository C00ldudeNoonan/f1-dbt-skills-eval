{#-
  dim_drivers version 1. DEPRECATED: removed after 2027-01-01, use version 2.
  Derived from v2 so the driver logic lives in one place; only the name
  columns differ. Placeholder rows keep the v1 shape: forename and surname
  null, full_name 'Unknown driver <id>'.
-#}
select
    driver_id,
    driver_ref,
    driver_code,
    permanent_number,
    current_number,
    iff(is_placeholder, null, first_name)                       as forename,
    iff(is_placeholder, null, last_name)                        as surname,
    iff(is_placeholder, 'Unknown driver ' || driver_id, first_name || ' ' || last_name) as full_name,
    nationality,
    date_of_birth,
    career_starts,
    career_wins,
    career_sprint_wins,
    career_podiums,
    world_championships,
    first_race_date,
    last_race_date,
    is_placeholder
from {{ ref('dim_drivers', v=2) }}
