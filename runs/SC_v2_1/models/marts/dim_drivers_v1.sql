-- v1: the original shape, with a single `full_name`. Deprecated 2027-01-01; use v2.
select
    driver_id,
    driver_ref,
    full_name,
    nationality,
    date_of_birth,
    current_number,
    is_placeholder,
    career_starts,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_f1__driver_profiles') }}
