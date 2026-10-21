-- Version 2 of dim_drivers. Replaces full_name with first_name and last_name.
select
    driver_id,
    driver_ref,
    first_name,
    last_name,
    nationality,
    date_of_birth,
    current_number,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_dim_drivers') }}
