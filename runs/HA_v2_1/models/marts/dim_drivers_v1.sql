{#
    dim_drivers version 1 (deprecated 2027-01-01). Same rows as version 2, with full_name instead
    of first_name and last_name. Logic lives in int_dim_drivers.
#}
select
    driver_id,
    driver_ref,
    full_name,
    nationality,
    date_of_birth,
    current_number,
    driver_code,
    is_placeholder,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_dim_drivers') }}
