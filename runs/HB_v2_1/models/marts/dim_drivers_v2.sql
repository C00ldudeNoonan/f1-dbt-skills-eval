{#
    dim_drivers version 2, the latest. Replaces v1 full_name with first_name and last_name.
    first_name is null for placeholder drivers, and last_name reads "Unknown driver <id>".
#}
select
    driver_id,
    driver_ref,
    current_number,
    driver_code,
    first_name,
    last_name,
    nationality,
    date_of_birth,
    is_placeholder,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships

from {{ ref('dim_drivers_base') }}
