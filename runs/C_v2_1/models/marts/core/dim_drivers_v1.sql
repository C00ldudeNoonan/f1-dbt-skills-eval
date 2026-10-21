-- dim_drivers version 1 (deprecated 2027-01-01): exposes full_name.
-- Version 2 replaces it with first_name and last_name.

select
    driver_id,
    driver_ref,
    driver_code,
    permanent_number,
    current_number,
    full_name,
    forename,
    surname,
    nationality,
    date_of_birth,
    career_starts,
    career_wins,
    career_sprint_wins,
    career_podiums,
    world_championships,
    first_race_date,
    last_race_date,
    is_placeholder
from {{ ref('int_f1__driver_profiles') }}
