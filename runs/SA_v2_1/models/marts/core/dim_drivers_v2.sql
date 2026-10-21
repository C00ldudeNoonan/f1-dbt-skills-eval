-- Version 2 (latest): `full_name` is replaced by `first_name` and `last_name`.
select
    driver_id,
    driver_ref,
    first_name,
    last_name,
    nationality,
    date_of_birth,
    current_number,
    is_placeholder,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_drivers') }}
