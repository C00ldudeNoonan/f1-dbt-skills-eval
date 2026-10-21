-- Version 1 (deprecated 2027-01-01): carries `full_name`. Kept building so existing consumers can migrate
-- to v2 (`first_name`, `last_name`) on their own schedule.
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
from {{ ref('int_driver_profiles') }}
