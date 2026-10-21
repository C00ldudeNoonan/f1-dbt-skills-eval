-- Version 1 (deprecated 2027-01-01): carries the combined full_name. Use v2 for first_name / last_name.
select
    driver_id,
    driver_ref,
    current_number,
    nullif(trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')), '') as full_name,
    nationality,
    date_of_birth,
    career_starts,
    career_race_entries_excl_dnq,
    career_wins,
    career_podiums,
    career_sprint_wins,
    world_championships
from {{ ref('int_f1__driver_profiles') }}
