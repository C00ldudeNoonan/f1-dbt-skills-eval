-- Version 1 (deprecated 2027-01-01): single `full_name` column. Builds as dim_drivers_v1; the
-- unversioned relation `dim_drivers` is a view dbt maintains on the latest version (v2).
select
    driver_id,
    driver_ref,
    trim(concat_ws(' ', first_name, last_name)) as full_name,
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
