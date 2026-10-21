{#
    dim_drivers version 1. Deprecated 2027-01-01, still built. Carries full_name.
    Use version 2 (first_name and last_name) for new work.
#}
select
    driver_id,
    driver_ref,
    current_number,
    driver_code,
    -- CONCAT_WS returns NULL in Snowflake when a part is NULL, so add the space only when a first name exists.
    concat(coalesce(first_name || ' ', ''), last_name) as full_name,
    nationality,
    date_of_birth,
    is_placeholder,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships

from {{ ref('dim_drivers_base') }}
