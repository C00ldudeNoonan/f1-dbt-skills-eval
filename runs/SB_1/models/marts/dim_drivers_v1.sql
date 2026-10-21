-- DEPRECATED (2027-01-01): use dim_drivers v2, which replaces full_name with first_name/last_name.
-- Derived from v2 so the career/championship logic lives in one place.
select
    driver_id,
    driver_ref,
    trim(concat_ws(' ', first_name, last_name))     as full_name,
    nationality,
    date_of_birth,
    current_number,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('dim_drivers', v=2) }}
