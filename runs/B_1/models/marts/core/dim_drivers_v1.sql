{#
    dim_drivers v1 (DEPRECATED 2027-01-01): compatibility layer over v2.
    Re-derives the v1 name columns (forename, surname, full_name) and keeps
    v1's column order. Still built into the original DIM_DRIVERS relation so
    existing readers are unaffected until the deprecation date. Contains no
    business logic of its own: all fixes go into dim_drivers_v2.sql.
#}

with v2 as (
    select * from {{ ref('dim_drivers', v=2) }}
)

select
    driver_id,
    driver_ref,
    driver_code,
    current_number,
    first_name                                      as forename,
    last_name                                       as surname,
    cast(first_name || ' ' || last_name as varchar) as full_name,
    nationality,
    date_of_birth,
    career_starts,
    career_wins,
    career_sprint_wins,
    career_podiums,
    career_points_scored,
    world_championships,
    first_race_date,
    last_race_date
from v2
