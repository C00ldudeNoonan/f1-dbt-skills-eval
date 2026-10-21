{#
    Version 1 of dim_drivers. Kept for consumers that still read full_name. Deprecated on 2027-01-01.
    Use version 2, which splits the name into first_name and last_name.
#}
select
    driver_id,
    driver_ref,
    current_number,
    forename || ' ' || surname as full_name,
    nationality,
    date_of_birth,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships,
    is_placeholder
from {{ ref('int_drivers_resolved') }}
