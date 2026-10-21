-- Version 1 of dim_drivers. Keeps `full_name`. Deprecated 2027-01-01; use version 2.
select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.forename || ' ' || drivers.surname as full_name,
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
