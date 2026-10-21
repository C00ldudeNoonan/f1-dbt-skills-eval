-- Version 2 of dim_drivers. `full_name` is replaced by `first_name` and `last_name`.
select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.forename as first_name,
    drivers.surname as last_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.driver_number as current_number,
    totals.career_starts,
    totals.career_wins,
    totals.career_podiums,
    totals.career_sprint_wins,
    totals.world_championships
from {{ ref('stg_ergast__drivers') }} as drivers
inner join {{ ref('int_driver_career_totals') }} as totals
    on drivers.driver_id = totals.driver_id
