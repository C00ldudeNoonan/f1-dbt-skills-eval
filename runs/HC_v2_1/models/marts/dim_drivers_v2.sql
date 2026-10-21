{#
    One row per driver. Version 2 of dim_drivers, the latest. Replaces full_name with first_name and last_name.
    Placeholder rows for late-arriving drivers have first_name 'Unknown' and last_name 'Driver <id>'.
#}
select
    driver_id,
    driver_ref,
    current_number,
    forename as first_name,
    surname as last_name,
    nationality,
    date_of_birth,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships,
    is_placeholder
from {{ ref('int_drivers_resolved') }}
