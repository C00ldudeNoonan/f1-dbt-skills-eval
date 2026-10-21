-- dim_drivers version 2 (latest): full_name is replaced by first_name and
-- last_name. Everything else matches version 1.

select
    driver_id,
    driver_ref,
    driver_code,
    permanent_number,
    current_number,
    first_name,
    last_name,
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
