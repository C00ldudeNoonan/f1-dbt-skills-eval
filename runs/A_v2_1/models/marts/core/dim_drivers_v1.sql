-- dim_drivers version 1 (deprecated 2027-01-01): single full_name column.
-- Built at the original DIM_DRIVERS relation so existing readers keep working.
select
    driver_id::integer as driver_id,
    is_placeholder::boolean as is_placeholder,
    driver_ref::varchar as driver_ref,
    driver_code::varchar as driver_code,
    current_number::integer as current_number,
    forename::varchar as forename,
    surname::varchar as surname,
    full_name::varchar as full_name,
    nationality::varchar as nationality,
    date_of_birth::date as date_of_birth,
    first_season::integer as first_season,
    last_season::integer as last_season,
    career_starts::integer as career_starts,
    career_wins::integer as career_wins,
    career_sprint_wins::integer as career_sprint_wins,
    career_podiums::integer as career_podiums,
    career_points::number(10, 2) as career_points,
    world_championships::integer as world_championships,
    url::varchar as url
from {{ ref('int_drivers__profile') }}
