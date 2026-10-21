-- Version 1 of dim_drivers. Deprecated 2027-01-01. Use dim_drivers_v2 (or ref('dim_drivers'), which resolves
-- to the latest version) for new work.
select
    driver_id,
    driver_ref,
    full_name,
    nationality,
    date_of_birth,
    current_number,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_dim_drivers') }}
