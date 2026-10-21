-- One row per driver with every driver attribute and career total. dim_drivers_v1 and dim_drivers_v2 select from here.
-- World championships count only seasons that are complete (see int_seasons).
with drivers as (

    select * from {{ ref('stg_f1__drivers') }}

),

career as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        count_if(is_win) as career_wins,
        count_if(is_podium) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_career as (

    select
        driver_id,
        count_if(is_win) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

titles as (

    select
        driver_id,
        count(*) as world_championships
    from {{ ref('mart_driver_season_standings') }}
    where championship_position = 1
        and is_season_complete
    group by driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    trim(drivers.forename) as first_name,
    trim(drivers.surname) as last_name,
    trim(concat_ws(' ', drivers.forename, drivers.surname)) as full_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.driver_number as current_number,
    coalesce(career.career_starts, 0) as career_starts,
    coalesce(career.career_wins, 0) as career_wins,
    coalesce(career.career_podiums, 0) as career_podiums,
    coalesce(sprint_career.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(titles.world_championships, 0) as world_championships
from drivers
left join career
    on career.driver_id = drivers.driver_id
left join sprint_career
    on sprint_career.driver_id = drivers.driver_id
left join titles
    on titles.driver_id = drivers.driver_id
