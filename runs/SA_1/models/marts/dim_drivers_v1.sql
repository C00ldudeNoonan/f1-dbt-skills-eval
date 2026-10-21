-- Deprecated: use dim_drivers v2 (first_name / last_name instead of full_name).
select
    drivers.driver_id,
    drivers.driver_ref,
    names.full_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.career_starts,
    drivers.career_wins,
    drivers.career_podiums,
    drivers.career_sprint_wins,
    drivers.world_championships,
    drivers.current_number
from {{ ref('int_driver_career') }} as drivers
inner join {{ ref('stg_drivers') }} as names using (driver_id)
