-- Version 2: full_name is replaced by first_name and last_name; everything else is unchanged.
select
    driver_id,
    driver_ref,
    current_number,
    first_name,
    last_name,
    nationality,
    date_of_birth,
    career_starts,
    career_race_entries_excl_dnq,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_f1__driver_profiles') }}
